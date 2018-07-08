describe "WePY autocompletions", ->
  [editor, provider] = []

  getCompletions = ->
    cursor = editor.getLastCursor()
    bufferPosition = cursor.getBufferPosition()
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    # https://github.com/atom/autocomplete-plus/blob/9506a5c5fafca29003c59566cfc2b3ac37080973/lib/autocomplete-manager.js#L57
    prefix = /(\b|['"~`!@#$%^&*(){}[\]=+,/?>])((\w+[\w-]*)|([.:;[{(< ]+))$/.exec(line)?[2] ? ''
    request =
      editor: editor
      bufferPosition: bufferPosition
      scopeDescriptor: cursor.getScopeDescriptor()
      prefix: prefix
    provider.getSuggestions(request)

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('autocomplete-wepy')
    # waitsForPromise -> atom.packages.activatePackage('language-wepy')

    runs ->
      provider = atom.packages.getActivePackage('autocomplete-wepy').mainModule.getProvider()

    waitsFor -> Object.keys(provider.completions).length > 0
    waitsForPromise -> atom.workspace.open('test.wpy')
    runs -> editor = atom.workspace.getActiveTextEditor()

  it "returns no completions when not at the start of a tag", ->
    editor.setText('')
    expect(getCompletions().length).toBe 0

    editor.setText('d')
    editor.setCursorBufferPosition([0, 0])
    expect(getCompletions().length).toBe 0
    editor.setCursorBufferPosition([0, 1])
    expect(getCompletions().length).toBe 0

  it "returns no completions in style tags", ->
    editor.setText """
      <style>
      <
      </style>
    """
    editor.setCursorBufferPosition([1, 1])
    expect(getCompletions().length).toBe 0

  it "returns no completions in script tags", ->
    editor.setText """
      <script>
      <
      </script>
    """
    editor.setCursorBufferPosition([1, 1])
    expect(getCompletions().length).toBe 0

  it "triggers autocomplete when an attibute has been inserted", ->
    spyOn(atom.commands, 'dispatch')
    suggestion = {type: 'attribute', text: 'whatever'}
    provider.onDidInsertSuggestion({editor, suggestion})

    advanceClock 1
    expect(atom.commands.dispatch).toHaveBeenCalled()

    args = atom.commands.dispatch.mostRecentCall.args
    expect(args[0].tagName.toLowerCase()).toBe 'atom-text-editor'
    expect(args[1]).toBe 'autocomplete-plus:activate'
