# -*- encoding: utf-8 -*-

##
# Setup global project settings for your apps. These settings are inherited by every subapp. You can
# override these settings in the subapps as needed.
#
Padrino.configure_apps do
  # enable :sessions
  set :session_secret, 'fc605690b6acf84ca154f3e17a55bb87212aa7af308070fc5edc8b17a8f55d7a'
  set :delivery_method, smtp: { 
    address: 'smtp.exmail.qq.com',
    port: 25,
    user_name: 'noreply@innshine.com',
    password: 'feiming123',
    authentication: :plain,
    enable_starttls_auto: true  
  }
  set :mailer_defaults, from: '买它 <noreply@innshine.com>'
end

# Mounts the core application for this project
Padrino.mount("Meta").to('/')