require "scripts/setup"

_ = require "underscore"
PrefixFree = require "prefixfree"
Bounce = require "bounce"

Events = require "scripts/events"
BaseView = require "scripts/views/base"
PreferencesView = require "scripts/views/preferences"
BoxView = require "scripts/views/box"
Events = require "scripts/events"

template = require "templates/app"

class App extends BaseView
  el: ".app"
  template: template

  events:
    "click .spin-link": "animateSpin"
    "click .play-button": "onClickPlay"
    "mousedown .box": "startBoxDrag"
    "ifChanged .loop-input, .slow-input": "playAnimation"

  initialize: ->
    super
    @preferences = new PreferencesView
    @boxView = new BoxView

    @$style = @$ "#animation"
    @$result = @$ "#result"
    @$box = @$result.find ".box"
    @$loop = @$ ".actions .loop-input"
    @$slow = @$ ".actions .slow-input"

    for checkbox in [@$loop, @$slow]
      checkbox.iCheck insert: "<i class=\"fa fa-check\"></i>"

    Events.on
      "animationOptionsChanged": @playAnimation
      "selectedPresetAnimation": @onSelectPreset
      "componentRemoved": @playAnimation

    @readURL()

  onClickPlay: ->
    if @preferences.getBounceObject().components.length
      @playAnimation()
    else
      $body = $ "body"
      $body.addClass "play-empty"
      clearTimeout(@playEmptyTimeout) if @playEmptyTimeout
      @playEmptyTimeout = setTimeout (-> $body.removeClass "play-empty"), 1000

  playAnimation: (options = {}) =>
    bounce = options.bounceObject or @preferences.getBounceObject()
    unless bounce.components.length
      window.location.hash = ""
      @$box.removeClass "animate"
      return

    duration = options.duration or bounce.duration
    duration *= 10 if @$slow.prop("checked") and not options.duration

    properties = []
    properties.push "animation-duration: #{duration}ms"
    properties.push("animation-iteration-count: infinite") if @$loop.prop("checked")

    css = """
    .box.animate {
      #{properties.join(";\n  ")};
    }
    #{bounce.getKeyframeCSS(name: "animation")}
    """

    @$style.text PrefixFree.prefixCSS(css, true)

    @$box.removeClass "animate"
    @$box[0].offsetWidth
    @$box.addClass "animate"

    @updateURL(bounce) unless options.updateURL is false

  animateSpin: (e) ->
    e.preventDefault()
    @preferences.selectPreset "spin"

  updateURL: (bounce) ->
    window.location.hash = @_encodeURL bounce.serialize()

  readURL: ->
    return unless window.location.hash
    @deserializeBounce window.location.hash[1..]

  onSelectPreset: (preset) =>
    window.location.hash = preset if preset
    @readURL()

  deserializeBounce: (str) =>
    return unless str
    bounce = new Bounce
    options = null
    try
      options = @_decodeURL(str)
      bounce.deserialize options.serialized
    catch e
      return

    @undelegateEvents()
    @$loop.iCheck(if options.loop then "check" else "uncheck")
    @delegateEvents @events

    @playAnimation bounceObject: bounce, updateURL: false
    @preferences.setFromBounceObject bounce

  @_shortKeys:
    "type": "T"
    "easing": "e"
    "duration": "d"
    "delay": "D"
    "from": "f"
    "to": "t"
    "bounces": "b"
    "stiffness": "s"

  @_shortValues:
    "bounce": "b"
    "sway": "s"
    "hardbounce": "B"
    "hardsway": "S"
    "scale": "c"
    "skew": "k"
    "translate": "t"
    "rotate": "r"

  @_longKeys: _.invert App._shortKeys
  @_longValues: _.invert App._shortValues

  _encodeURL: (serialized) ->
    encoded = {}
    encoded.l = 1 if @$loop.prop("checked")
    encoded.s = for options in serialized
      shortKeys = {}
      for key, value of options
        shortKeys[App._shortKeys[key] or key] =
          App._shortValues[value] or value

      shortKeys

    stringified = JSON.stringify(encoded)
    # Remove double quotes in properties
    stringified.replace(/(\{|,)"([a-z0-9]+)"(:)/gi, "$1$2$3")


  _decodeURL: (str) ->
    # Add back the double quotes in properties
    json = str.replace(/(\{|,)([a-z0-9]+)(:)/gi, "$1\"$2\"$3")
    decoded = JSON.parse(json)
    unshortened = for options in decoded.s
      longKeys = {}
      for key, value of options
        longKeys[App._longKeys[key] or key] =
          App._longValues[value] or value

      longKeys

    {
      serialized: unshortened
      loop: decoded.l
    }

module.exports = App