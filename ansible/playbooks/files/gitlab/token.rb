if PersonalAccessToken.find_by_token(ENV.fetch('GITLAB_ADMIN_TOKEN'))
  puts 'exists'
else
  token = User.find_by_username('root').personal_access_tokens.build(name: 'terraform', scopes: ['api'], expires_at: 365.days.from_now)
  token.set_token(ENV.fetch('GITLAB_ADMIN_TOKEN'))
  token.save!
  puts 'created'
end
