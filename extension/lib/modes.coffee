###
# Copyright Anton Khodakivskiy 2013.
# Copyright Simon Lydell 2013, 2014.
# Copyright Wang Zhuochun 2014.
#
# This file is part of VimFx.
#
# VimFx is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# VimFx is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with VimFx.  If not, see <http://www.gnu.org/licenses/>.
###

utils                   = require('./utils')
{ mode_hints }          = require('./mode-hints/mode-hints')
{ updateToolbarButton } = require('./button')
{ searchForMatchingCommand
, isEscCommandKey
, isReturnCommandKey
, findStorage }         = require('./commands')

{ interfaces: Ci } = Components

XULDocument = Ci.nsIDOMXULDocument

exports['normal'] =
  onEnter: (vim, storage) ->
    storage.keys ?= []
    storage.commands ?= {}

  onLeave: (vim, storage) ->
    storage.keys.length = 0

  onInput: (vim, storage, keyStr, event) ->
    isEditable = utils.isElementEditable(event.originalTarget)
    autoInsertMode = isEditable or vim.rootWindow.TabView.isVisible()

    if autoInsertMode and not isEscCommandKey(keyStr)
      return false

    storage.keys.push(keyStr)

    { match, exact, command, count } = searchForMatchingCommand(storage.keys)

    if match
      if exact
        command.func(vim, event, count)
        storage.keys.length = 0

      # Esc key is not suppressed, and passed to the browser in normal mode.
      #
      # - It allows for stopping the loading of the page.
      # - It allows for closing many custom dialogs (and perhaps other things
      #   -- Esc is a very commonly used key).
      # - It is not passed if Esc is used for `command_Esc` and we’re blurring
      #   an element. That allows for blurring an input in a custom dialog
      #   without closing the dialog too.
      # - There are two reasons we might suppress it in other modes. If some
      #   custom dialog of a website is open, we should be able to cancel hint
      #   markers on it without closing it. Secondly, otherwise cancelling hint
      #   markers on Google causes its search bar to be focused.
      # - It may only be suppressed in web pages, not in browser chrome. That
      #   allows for reseting the location bar when blurring it, and closing
      #   dialogs such as the “bookmark this page” dialog (<c-d>).
      document = event.originalTarget.ownerDocument
      inBrowserChrome = (document instanceof XULDocument)
      if keyStr == 'Esc' and (not autoInsertMode or inBrowserChrome)
        return false

      return true

    else
      storage.keys.length = 0 unless /\d/.test(keyStr)

      return false

exports['insert'] =
  onEnter: (vim) ->
    updateToolbarButton(vim.rootWindow, {insertMode: true})
  onLeave: (vim) ->
    updateToolbarButton(vim.rootWindow, {insertMode: false})
    utils.blurActiveElement(vim.window)
  onInput: (vim, storage, keyStr) ->
    if isEscCommandKey(keyStr)
      vim.enterMode('normal')
      return true

exports['find'] =
  onEnter: ->

  onLeave: (vim) ->
    findBar = vim.rootWindow.gBrowser.getFindBar()
    findStorage.lastSearchString = findBar._findField.value

  onInput: (vim, storage, keyStr) ->
    findBar = vim.rootWindow.gBrowser.getFindBar()
    if isEscCommandKey(keyStr) or keyStr == 'Return'
      findBar.close()
      return true
    return false

exports['hints'] = mode_hints