local jwt = require 'resty.jwt'
local jwt_secret = os.getenv('JWT_SECRET')

local is_authorized, user_id = (function(authorization)
  --local authorization = ngx.var.http_authorization
  if not authorization then return false end

  local _, _, token = string.find(authorization, "Bearer%s+(.+)")
  local jwt_obj = jwt:verify(jwt_secret, token)
  return jwt_obj and jwt_obj.valid, jwt_obj.payload.user_id
end)("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJyb2xlIjoid2VidXNlciJ9.uSsS2cukBlM6QXe4Y0H90fsdkJSGcle9b7p_kMV1Ymk")

if not is_authorized then
  ngx.status = ngx.HTTP_UNAUTHORIZED
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
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

local res = http_client:request_uri(stripe_endpoint .. '/charges', {
  method = "POST",
  headers = {
      ['Authorization'] = stripe_auth_header,
  },
  body = ngx.encode_args({
      amount = 9900,
      currency = 'usd',
      description = 'Khumbu Icefall Service',
      customer = stripe_customer_id
  })
})

ngx.say(res.body)
