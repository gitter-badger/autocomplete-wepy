provider = require './provider'

module.exports =
  activate: (state) ->
    unless atom.inSpecMode()
      require('atom-package-deps').install 'autocomplete-wepy', true

  getProvider: -> provider
