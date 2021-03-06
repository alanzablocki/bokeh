_ = require "underscore"

CategoricalMapper = require "../mappers/categorical_mapper"
GridMapper = require "../mappers/grid_mapper"
LinearMapper = require "../mappers/linear_mapper"
LogMapper = require "../mappers/log_mapper"
Range1d = require "../ranges/range1d"

{EQ, GE}  = require "../../core/layout/solver"
LayoutCanvas = require "../../core/layout/layout_canvas"
{logging} = require "../../core/logging"
p = require "../../core/properties"

class CartesianFrame extends LayoutCanvas.Model
  type: 'CartesianFrame'

  initialize: (attrs, options) ->
    super(attrs, options)
    @panel = @

    @_configure_mappers()
    @listenTo(@, 'change', () => @_configure_mappers())

    return null

  _doc_attached: () ->
    @listenTo(@document.solver(), 'layout_update', () => @_update_mappers())
    return null

  contains: (vx, vy) ->
    return (
      vx >= @left and vx <= @right and
      vy >= @bottom and vy <= @top
    )

  map_to_screen: (x, y, canvas, x_name='default', y_name='default') ->
    vx = @x_mappers[x_name].v_map_to_target(x)
    sx = canvas.v_vx_to_sx(vx)

    vy = @y_mappers[y_name].v_map_to_target(y)
    sy = canvas.v_vy_to_sy(vy)
    return [sx, sy]

  _get_ranges: (range, extra_ranges) ->
    ranges = {}
    ranges['default'] = range
    if extra_ranges?
      for name, extra_range of extra_ranges
        ranges[name] = extra_range
    return ranges

  _get_mappers: (mapper_type, ranges, frame_range) ->
    mappers = {}
    for name, range of ranges
      if range.type == "Range1d" or range.type == "DataRange1d"
        if mapper_type == "log"
          mapper_model = LogMapper.Model
        else
          mapper_model = LinearMapper.Model
      else if range.type == "FactorRange"
        mapper_model = CategoricalMapper.Model
      else
        logger.warn("unknown range type for range '#{name}': #{range}")
        return null
      mappers[name] = new mapper_model({
        source_range: range
        target_range: frame_range
      })
    return mappers

  _configure_frame_ranges: () ->
    @_h_range = new Range1d.Model({start: @left,   end: @left   + @width})
    @_v_range = new Range1d.Model({start: @bottom, end: @bottom + @height})

  _configure_mappers: () ->
    @_configure_frame_ranges()

    @_x_ranges = @_get_ranges(@x_range, @extra_x_ranges)
    @_y_ranges = @_get_ranges(@y_range, @extra_y_ranges)

    @_x_mappers = @_get_mappers(@x_mapper_type, @_x_ranges, @_h_range)
    @_y_mappers = @_get_mappers(@y_mapper_type, @_y_ranges, @_v_range)

  _update_mappers: () ->
    @_configure_frame_ranges()

    for name, mapper of @_x_mappers
      mapper.target_range = @_h_range
    for name, mapper of @_y_mappers
      mapper.target_range = @_v_range
    return null

  @getters {
    h_range:   () -> @_h_range
    v_range:   () -> @_v_range
    x_ranges:  () -> @_x_ranges
    y_ranges:  () -> @_y_ranges
    x_mappers: () -> @_x_mappers
    y_mappers: () -> @_y_mappers
  }

  @internal {
    extra_x_ranges: [ p.Any, {} ]
    extra_y_ranges: [ p.Any, {} ]
    x_range:        [ p.Instance ]
    y_range:        [ p.Instance ]
    x_mapper_type:  [ p.String, 'auto' ]
    y_mapper_type:  [ p.String, 'auto' ]
  }

  get_constraints: () ->
    constraints = []
    constraints.push(GE(@_top))
    constraints.push(GE(@_bottom))
    constraints.push(GE(@_left))
    constraints.push(GE(@_right))
    constraints.push(GE(@_width))
    constraints.push(GE(@_height))
    constraints.push(EQ(@_left, @_width, [-1, @_right]))
    constraints.push(EQ(@_bottom, @_height, [-1, @_top]))
    return constraints

module.exports =
  Model: CartesianFrame
