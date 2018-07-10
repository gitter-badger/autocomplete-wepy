COMPLETIONS = require '../completions.json'

attributePattern = /\s+([a-zA-Z][-a-zA-Z]*)\s*=\s*$/
tagPattern = /<([a-zA-Z][-a-zA-Z]*)(?:\s|$)/
functionNamePattern = /wepy.([a-zA-Z][-a-zA-Z]*)\s*\(/
functionArgumentKeyPattern = /"([a-zA-Z][-a-zA-Z]*)"\s*:/g
functionPreviousKeywordPattern = /\s*(wepy)./
module.exports =
  selector: '.text.html.wepy'
  disableForSelector: '.text.html.wepy .comment'
  filterSuggestions: true
  inclusionPriority: 1
  excludeLowerPriority: true
  suggestionPriority: 2

  completions: COMPLETIONS

  getSuggestions: (request) ->
    if @isAttributeValueStart(request)
      @getAttributeValueCompletions(request)
    else if @isAttributeStart(request)
      @getAttributeNameCompletions(request)
    else if @isTagStart(request)
      @getTagNameCompletions(request)
    else if @isFunctionStart(request)
      @getFunctionCompletions(request)
    else if @isFunctionArgumentKeyStart(request)
      @getFunctionArgumentKeyCompletions(request)
    else if @isFunctionArgumentValueStart(request)
      @getFunctionArgumentValueCompletions(request)
    else
      []

  onDidInsertSuggestion: ({editor, suggestion}) ->
    if suggestion.type is 'attribute'
      setTimeout(@triggerAutocomplete.bind(this, editor), 1)
    else if suggestion.type is 'variable'
      setTimeout(@triggerAutocomplete.bind(this, editor), 1)

  triggerAutocomplete: (editor) ->
    atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:activate', activatedManually: false)

  isFunctionStart: ({prefix, scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    line = editor.lineTextForBufferRow(bufferPosition.row)
    keywordPrevious = functionPreviousKeywordPattern.exec(line)?[1]
    scopes.includes('source.js.embedded.html') and
      keywordPrevious is 'wepy'

  isFunctionArgumentValueStart: ({scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    quoteIndex = Math.max(0, bufferPosition.column - 1)
    while quoteIndex >= 0
        preScopeDescriptor = editor.scopeDescriptorForBufferPosition([bufferPosition.row, quoteIndex])
        scopes = preScopeDescriptor.getScopesArray()
        if not this.hasJsStringScope(scopes) or scopes.includes('punctuation.definition.string.begin.js')
            break
        quoteIndex--

    quotePrevious = editor.getTextInBufferRange([[bufferPosition.row, Math.max(0, quoteIndex-2)], [bufferPosition.row, quoteIndex]])
    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()

    # autocomplete here: {"|":""}
    # not here: {|"":""}
    # or here: {""|:""}
    # or here: {"""|:""}
    # or here: {"":"|"}

    @hasJsStringScope(scopes) and @hasJsStringScope(previousScopesArray) and
      previousScopesArray.indexOf('punctuation.definition.string.end.html') is -1 and
      scopes.includes('source.js.embedded.html') and
      scopes.includes('meta.arguments.js') and
      quotePrevious.trim().indexOf(':') isnt -1

  isFunctionArgumentKeyStart: ({scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    quoteIndex = Math.max(0, bufferPosition.column - 1)
    while quoteIndex >= 0
        preScopeDescriptor = editor.scopeDescriptorForBufferPosition([bufferPosition.row, quoteIndex])
        scopes = preScopeDescriptor.getScopesArray()
        if not this.hasJsStringScope(scopes) or scopes.includes('punctuation.definition.string.begin.js')
            break
        quoteIndex--

    quotePrevious = editor.getTextInBufferRange([[bufferPosition.row, Math.max(0, quoteIndex-2)], [bufferPosition.row, quoteIndex]])
    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()
    editor.getTextInBufferRange([[bufferPosition.row, 0], [bufferPosition.row, quoteIndex]])
    # autocomplete here: {"|":""}
    # not here: {|"":""}
    # or here: {""|:""}
    # or here: {"""|:""}
    # or here: {"":"|"}

    @hasJsStringScope(scopes) and @hasJsStringScope(previousScopesArray) and
      previousScopesArray.indexOf('punctuation.definition.string.end.html') is -1 and
      scopes.includes('source.js.embedded.html') and
      scopes.includes('meta.arguments.js') and
      quotePrevious.trim().indexOf(':') is -1

  buildFunctionArgmentKeyCompletion: (tag, {description}) ->
    text: tag
    type: 'value'
    description: description ? "HTML <#{tag}> tag"
    descriptionMoreURL: if description then @getTagDocsURL(tag) else null

  isTagStart: ({prefix, scopeDescriptor, bufferPosition, editor}) ->
    return @hasTagScope(scopeDescriptor.getScopesArray()) if prefix.trim() and prefix.indexOf('<') is -1

    # autocomplete-plus's default prefix setting does not capture <. Manually check for it.
    prefix = editor.getTextInRange([[bufferPosition.row, bufferPosition.column - 1], bufferPosition])

    scopes = scopeDescriptor.getScopesArray()

    # Don't autocomplete in embedded languages
    prefix is '<' and scopes[0] is 'text.html.basic' and scopes.length is 1

  isAttributeStart: ({prefix, scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    return @hasTagScope(scopes) if not @getPreviousAttribute(editor, bufferPosition) and prefix and not prefix.trim()

    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()

    return true if previousScopesArray.indexOf('entity.other.attribute-name.html') isnt -1
    return false unless @hasTagScope(scopes)

    # autocomplete here: <tag |>
    # not here: <tag >|
    scopes.indexOf('punctuation.definition.tag.end.html') isnt -1 and
      previousScopesArray.indexOf('punctuation.definition.tag.end.html') is -1

  isAttributeValueStart: ({scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()

    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()

    # autocomplete here: attribute="|"
    # not here: attribute=|""
    # or here: attribute=""|
    # or here: attribute="""|
    @hasStringScope(scopes) and @hasStringScope(previousScopesArray) and
      previousScopesArray.indexOf('punctuation.definition.string.end.html') is -1 and
      @hasTagScope(scopes) and
      @getPreviousAttribute(editor, bufferPosition)?

  hasTagScope: (scopes) ->
    for scope in scopes
      return true if scope.startsWith('meta.tag.') and scope.endsWith('.html')
    return false

  hasStringScope: (scopes) ->
    scopes.indexOf('string.quoted.double.html') isnt -1 or
      scopes.indexOf('string.quoted.single.html') isnt -1

  hasJsStringScope: (scopes) ->
    scopes.indexOf('string.quoted.double.js') isnt -1 or
      scopes.indexOf('string.quoted.single.js') isnt -1

  getFunctionCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    for tag, options of @completions.functions when not prefix or prefix is '.'  or firstCharsEqual(tag, prefix)
      completions.push(@buildFunctionCompletion(tag, options))
    completions

  buildFunctionCompletion: (tag, {description,promise}) ->
    snippet: "#{tag}({${1}})"
    displayText : tag
    type: 'function'
    leftLabel: if promise then "Promise" else "void"
    rightLabel: "Object"
    description: description ? "HTML <#{tag}> tag"
    descriptionMoreURL: if description then @getTagDocsURL(tag) else null

  getFunctionArgumentKeyCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    func = @getPreviousFunctionName(editor, bufferPosition)
    values = @completions.functions[func]?.params ? []
    for value in values when not prefix or firstCharsEqual(value, prefix)
      completions.push(@buildFunctionArgumentKeyCompletion(func, value))
    completions

  getFunctionArgumentValueCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    func = @getPreviousFunctionName(editor, bufferPosition)
    key = @getPrevFunctionArgumentKey(editor, bufferPosition)
    values = @completions.params["#{func}/#{key}"]?.options ? []
    for value in values when not prefix or firstCharsEqual(value, prefix)
      completions.push(@buildFunctionArgumentValueCompletion(value))
    completions

  buildFunctionArgumentValueCompletion: (value) ->
    text : value
    type: 'value'

  buildFunctionArgumentKeyCompletion: (func, value) ->
    snippet: "#{value}\": \"${1}"
    displayText : value
    type: 'variable'
    description:  @completions.params["#{func}/#{value}"]?.description ? null

  getTagNameCompletions: ({prefix, editor, bufferPosition}) ->
    # autocomplete-plus's default prefix setting does not capture <. Manually check for it.
    ignorePrefix = editor.getTextInRange([[bufferPosition.row, bufferPosition.column - 1], bufferPosition]) is '<'

    completions = []
    for tag, options of @completions.tags when ignorePrefix or firstCharsEqual(tag, prefix)
      completions.push(@buildTagCompletion(tag, options))
    completions

  buildTagCompletion: (tag, {description}) ->
    text: tag
    type: 'tag'
    description: description ? "HTML <#{tag}> tag"
    descriptionMoreURL: if description then @getTagDocsURL(tag) else null

  getAttributeNameCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    tag = @getPreviousTag(editor, bufferPosition)
    tagAttributes = @getTagAttributes(tag)

    for attribute in tagAttributes when not prefix.trim() or firstCharsEqual(attribute, prefix)
      tagandattr = "#{tag}/#{attribute}"
      attributes = []
      if @completions.attributes[tagandattr]
        attributes = @completions.attributes[tagandattr]
      else
        attributes =@completions.attributes[attribute]
      completions.push(@buildLocalAttributeCompletion(attribute, tag, attributes))

    for attribute, options of @completions.attributes when not prefix.trim() or firstCharsEqual(attribute, prefix)
      completions.push(@buildGlobalAttributeCompletion(attribute, options)) if options.global

    completions

  buildLocalAttributeCompletion: (attribute, tag, options) ->
    snippet: if options?.type is 'flag' then attribute else "#{attribute}=\"$1\"$0"
    displayText: attribute
    type: 'attribute'
    rightLabel: "<#{tag}>"
    description: if options?.description? then options.description else "#{attribute} attribute local to <#{tag}> tags"
    # descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)

  buildGlobalAttributeCompletion: (attribute, {description, type}) ->
    snippet: if type is 'flag' then attribute else "#{attribute}=\"$1\"$0"
    displayText: attribute
    type: 'attribute'
    description: description ? "Global #{attribute} attribute"
    # descriptionMoreURL: if description then @getGlobalAttributeDocsURL(attribute) else null

  getAttributeValueCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    tag = @getPreviousTag(editor, bufferPosition)
    attribute = @getPreviousAttribute(editor, bufferPosition)
    values = @getAttributeValues(tag, attribute)
    for value in values when not prefix or firstCharsEqual(value, prefix)
      completions.push(@buildAttributeValueCompletion(tag, attribute, value))

    if completions.length is 0 and @completions.attributes[attribute]?.type is 'boolean'
      completions.push(@buildAttributeValueCompletion(tag, attribute, 'true'))
      completions.push(@buildAttributeValueCompletion(tag, attribute, 'false'))

    completions

  buildAttributeValueCompletion: (tag, attribute, value) ->
    valueOption = "#{tag}/#{attribute}/#{value}"
    description = @completions.values[valueOption]?.description
    version = @completions.values[valueOption]?.version
    label = ""
    if version
      label = "#{description}\n最低版本 #{version}"
    else
      label = description

    text: value
    type: 'value'
    rightLabel: "<#{tag}>"
    description: label
    # descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)

  getPreviousTag: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      tag = tagPattern.exec(editor.lineTextForBufferRow(row))?[1]
      return tag if tag
      row--
    return

  getPrevFunctionArgumentKey: (editor, bufferPosition) ->
    lastIndex = 1
    {row} = bufferPosition
    line = editor.lineTextForBufferRow(row)
    name = ''
    while lastIndex > 0
      temp = functionArgumentKeyPattern.exec(line)?[1]
      lastIndex = functionArgumentKeyPattern.lastIndex
      if temp isnt undefined
        name = temp
    return name if name

  getPreviousFunctionName: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      name = functionNamePattern.exec(editor.lineTextForBufferRow(row))?[1]
      return name if name
      row--
    return

  getPreviousAttribute: (editor, bufferPosition) ->
    # Remove everything until the opening quote (if we're in a string)
    quoteIndex = bufferPosition.column - 1 # Don't start at the end of the line
    while quoteIndex
      scopes = editor.scopeDescriptorForBufferPosition([bufferPosition.row, quoteIndex])
      scopesArray = scopes.getScopesArray()
      break if not @hasStringScope(scopesArray) or scopesArray.indexOf('punctuation.definition.string.begin.html') isnt -1
      quoteIndex--

    attributePattern.exec(editor.getTextInRange([[bufferPosition.row, 0], [bufferPosition.row, quoteIndex]]))?[1]

  getAttributeValues: (tag, attribute) ->
    # Some local attributes are valid for multiple tags but have different attribute values
    # To differentiate them, they are identified in the completions file as tag/attribute
    @completions.attributes[attribute]?.attribOption ? @completions.attributes["#{tag}/#{attribute}"]?.attribOption ? []

  getFunctionArgumentValues: (name, key) ->
    # Some local attributes are valid for multiple tags but have different attribute values
    # To differentiate them, they are identified in the completions file as tag/attribute
    @completions.functions['key']?.params ? @completions.attributes["#{tag}/#{attribute}"]?.attribOption ? []

  getTagAttributes: (tag) ->
    @completions.tags[tag]?.attributes ? []

  getTagDocsURL: (tag) ->
    "https://developers.weixin.qq.com/miniprogram/dev/component/#{tag}.html"

  getLocalAttributeDocsURL: (attribute, tag) ->
    "#{@getTagDocsURL(tag)}#attr-#{attribute}"

  getGlobalAttributeDocsURL: (attribute) ->
    "https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/#{attribute}"

firstCharsEqual = (str1, str2) ->
  str1[0].toLowerCase() is str2[0].toLowerCase()
