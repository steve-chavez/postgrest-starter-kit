local jwt = require 'resty.jwt'
local jwt_secret = os.getenv('JWT_SECRET')

local is_authorized = (function()
  local authorization = ngx.var.http_authorization
  if not authorization then return false end

  local token = authorization:gsub('Bearer ', '')
  local jwt_obj = jwt:verify(jwt_secret, token)
  return jwt_obj and jwt_obj.valid
end)()

if not is_authorized then
  ngx.status = ngx.HTTP_UNAUTHORIZED
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.say('true')
