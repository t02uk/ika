THREE.Vector3.prototype.summary = ->
  d = 4
  "{#{@x.toFixed(d)}, #{@y.toFixed(d)}, #{@z.toFixed(d)}}"
