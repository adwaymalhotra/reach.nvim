local module = {}

module.auto_handles = vim.split(
  '123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~',
  ''
)

module.colemak = vim.split(
  "tnseriaoplfuwyhdcqzbjvk4738291056;,./", ""
)

return module
