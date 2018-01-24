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

local plan_ids = {"gpl", "mit", "regular-sub", "enterprise-sub"};

local item = ngx.req.get_uri_args().item

if not (item == plan_ids[1] or item == plan_ids[2] or item == plan_ids[3] or item == plan_ids[4]) then
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

local res = http_client:request_uri(stripe_endpoint .. '/customers/' .. stripe_customer_id .. '/subscriptions', {
  method = "POST",
  headers = {
      ['Authorization'] = stripe_auth_header,
  },
  body = ngx.encode_args({
      plan = item
  })
})

if ngx.status > 206 then
  return ngx.say(res.body)
end

local charge_id, cus_id = (function()
  local body = cjson.decode(res.body)
  return body['id'], body['customer']
end)()


local payment_handler_authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIiA6ICJwYXltZW50X2hhbmRsZXIiLCAidXNlcl9pZCIgOiAzLCAiZXhwIiA6IDE1MTY4NDIxNzB9.0oeGzkA1rJ7N3iRewWH79vXsGGl--bjh43woKJEI9tE"

ngx.req.set_header("Authorization", payment_handler_authorization)
ngx.req.set_header("Prefer", "return=minimal")
ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")

local res = ngx.location.capture('/rest/charges', {
  method = ngx.HTTP_POST,
  body = ngx.encode_args({
      id = charge_id,
      cus_id = cus_id
  })
})

ngx.status = res.status

if ngx.status > 206 then
  return ngx.say(res.body)
end

ngx.say("Success")
