local jwt = require 'resty.jwt'
local jwt_secret = os.getenv('JWT_SECRET')

local is_authorized, user_id = (function()
  -- Hardcoded for now, uncomment this later
  --local authorization = ngx.var.http_authorization
  local authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlIjoid2VidXNlciJ9.uSsS2cukBlM6QXe4Y0H90fsdkJSGcle9b7p_kMV1Ymk"
  if not authorization then return false end

  local _, _, token = string.find(authorization, "Bearer%s+(.+)")
  local jwt_obj = jwt:verify(jwt_secret, token)
  return jwt_obj and jwt_obj.valid, jwt_obj.payload.user_id
end)()

if not is_authorized then
  ngx.status = ngx.HTTP_UNAUTHORIZED
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local item_ids = {"gpl", "mit", "regular-sub", "enterprise-sub"};

local item_id = ngx.req.get_uri_args().item

local amount, description, is_plan = (function()
  if item_id == item_ids[1] then return 1999, "GPL License", false
  elseif item_id == item_ids[2] then return 9999, "MIT License", false
  elseif item_id == item_ids[3] then return 1999, "subZero regular subscription", true
  elseif item_id == item_ids[4] then return 2999, "subZero Enterprise subscription", true
  else return nil, nil, nil
  end
end)()

if not amount then
  ngx.status = ngx.HTTP_BAD_REQUEST
  ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local stripe_secret_key = os.getenv('STRIPE_SECRET_KEY')
local stripe_endpoint = 'https://api.stripe.com/v1'
local stripe_auth_header = 'Basic ' .. ngx.encode_base64(stripe_secret_key ..':')

ngx.req.read_body()
local args = ngx.req.get_post_args()

local http = require "resty.http"
local http_client = http.new()

local res, err = http_client:request_uri(stripe_endpoint .. '/customers', {
  method = "POST",
  headers = {
      ['Authorization'] = stripe_auth_header
  },
  body = ngx.encode_args({
      ['metadata[user_id]'] = user_id,
      source = args.stripeToken,
      email = args.stripeEmail
  })
})

ngx.status = res.status

if ngx.status > 206 then
  return ngx.say(res.body)
end

local cjson = require 'cjson'
local stripe_customer_id = cjson.decode(res.body)['id']

local res = (function()
  if is_plan then
    return http_client:request_uri(stripe_endpoint .. '/customers/' .. stripe_customer_id .. '/subscriptions', {
      method = "POST",
      headers = {
          ['Authorization'] = stripe_auth_header,
      },
      body = ngx.encode_args({
          plan = item_id
      })
    })
  else
    return http_client:request_uri(stripe_endpoint .. '/charges', {
      method = "POST",
      headers = {
          ['Authorization'] = stripe_auth_header,
      },
      body = ngx.encode_args({
          amount = amount,
          currency = 'usd',
          description = description,
          customer = stripe_customer_id
      })
    })
  end
end)()

if ngx.status > 206 then
  return ngx.say(res.body)
end

local charge_id, cus_id = (function()
  local body = cjson.decode(res.body)
  return body['id'], body['customer']
end)()

local pgmoon = require("pgmoon")
local pg = pgmoon.new({
  host = os.getenv('DB_HOST'),
  port = os.getenv('DB_PORT'),
  database = os.getenv('DB_NAME'),
  user = os.getenv('SUPER_USER'),
  password = os.getenv('SUPER_USER_PASSWORD')
})

assert(pg:connect())

assert(pg:query("insert into data.charge(id, cus_id) values(" ..  table.concat({pg:escape_literal(charge_id), pg:escape_literal(cus_id)}, ",") .. ")"))

pg:keepalive()

ngx.say(true)
