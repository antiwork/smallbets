json.name                   h(user.name)
json.ascii_name             user.ascii_name
json.twitter_username       user.twitter_username
json.linkedin_username      user.linkedin_username
json.value                  user.id
json.avatar_url             user.is_a?(Everyone) ? nil : user_image_path(user)
json.sgid                   user.attachable_sgid
