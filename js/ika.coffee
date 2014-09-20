'use strict'

ikaMain = ->
  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(90, 640.0 / 480.0, Math.pow(0.1, 8), Math.pow(10, 3))
  renderer = new THREE.WebGLRenderer(antialias: true)
  renderer.setFaceCulling("front_and_back")
  c = document.getElementById('c')
  renderer.setSize(640, 480)
  c.appendChild(renderer.domElement)

  class World
    @setup: (scene) ->
      @size = 0.5
      # setup for cube
      # the geometry cube is given on library. But is triangle base.
      # so we can see triangle on the face of cube.
      vertices = [
        new THREE.Vector3(-@size,-@size,-@size),
        new THREE.Vector3( @size,-@size,-@size),
        new THREE.Vector3( @size, @size,-@size),
        new THREE.Vector3(-@size, @size,-@size),
        new THREE.Vector3(-@size,-@size, @size),
        new THREE.Vector3( @size,-@size, @size),
        new THREE.Vector3( @size, @size, @size),
        new THREE.Vector3(-@size, @size, @size)
      ]
      
      @geometry = new THREE.Geometry()
      @geometry.vertices.push(
        vertices[0],
        vertices[1],
        vertices[2],
        vertices[3],
        vertices[7],
        vertices[4],
        vertices[5],
        vertices[6],
        vertices[2],
        vertices[6],
        vertices[7],
        vertices[3],
        vertices[0],
        vertices[4],
        vertices[5],
        vertices[1],
      )


      @material = new THREE.LineBasicMaterial
        color: 0x222233
        depthTest: false
        transparent: true
        blending: THREE.AdditiveBlending

      @mesh = new THREE.Line(@geometry, @material)

      scene.add(@mesh)

  class Water
    class WaterBone
      @_id: 0
      @material: new THREE.MeshBasicMaterial
          color: 0x333399
          depthTest: false
          transparent: true
          blending: THREE.AdditiveBlending
          side: THREE.DoubleSide

      constructor: (scene, p) ->
        @id = WaterBone._id++
        @speed = new THREE.Vector3(0, 0, 0)
        s = 0.002
        @geometry = new THREE.BoxGeometry(s, s, s)
        @mesh = new THREE.Mesh(@geometry, WaterBone.material)
        @mesh.position.set(p.x, p.y, p.z)
        scene.add(@mesh)
      position: ->
        @mesh.position

    @surfaceMaterial: new THREE.MeshBasicMaterial
      color: 0x141744
      transparent: true
      depthTest: false
      blending: THREE.AdditiveBlending
      side: THREE.DoubleSide

    @sideMaterial: new THREE.MeshBasicMaterial
      color: 0x090b2a
      transparent: true
      depthTest: false
      blending: THREE.AdditiveBlending
      side: THREE.DoubleSide

    @bottomMaterial: new THREE.MeshBasicMaterial
      color: 0x010111
      transparent: true
      depthTest: false
      blending: THREE.AdditiveBlending
      side: THREE.DoubleSide

    constructor: (scene) ->
      step = 0.10
      i = 0
      @bones = for x in [-World.size ... World.size + 0.001] by step
        df = if i % 2 is 0 then 0 else step * 0.5
        i++
        for z in [-World.size - df ... World.size + 0.001 + df] by step
          z = if z < -World.size
            z = -World.size
          else if z > World.size
            z = World.size
          else
            z
          new WaterBone(scene, x: x, y: 0.0, z: z)

      @surfaceGeometry = new THREE.Geometry()
      @bonesFlatten = []
      for x in _.chain(@bones).flatten().sortBy((x) => x.id).value()
        @surfaceGeometry.vertices.push(x.position())
        @bonesFlatten.push(x)

      for x in [0 ... @bones.length]
        for z in [0 ... @bones[x].length]
          triangles = if x % 2 is 0
            [
              [
                [x,     z],
                [x, z - 1],
                [x - 1, z],
              ],
              [
                [x,     z],
                [x + 1, z],
                [x, z - 1],
              ]
            ]
          else
            [
              [
                [x,     z],
                [x - 1, z],
                [x, z + 1]
              ], [
                [x,     z],
                [x, z + 1]
                [x + 1, z],
              ]
            ]
          for triangle in triangles
            fault = false
            for v in triangle
              fault = @bones[v[0]] is undefined or @bones[v[0]][v[1]] is undefined
              break if fault

            continue if fault
          
            face = new THREE.Face3(
              @bones[triangle[0][0]][triangle[0][1]].id,
              @bones[triangle[1][0]][triangle[1][1]].id,
              @bones[triangle[2][0]][triangle[2][1]].id
            )

            @surfaceGeometry.faces.push(face)
            
      @surfaceMesh = new THREE.Mesh(@surfaceGeometry, Water.surfaceMaterial)
      scene.add(@surfaceMesh)

      # bottom
      @bottomGeometry = new THREE.Geometry()
      @bottomGeometry.vertices.push(
        new THREE.Vector3(-0.5,-0.5,-0.5),
        new THREE.Vector3(-0.5,-0.5, 0.5),
        new THREE.Vector3( 0.5,-0.5,-0.5),
        new THREE.Vector3( 0.5,-0.5, 0.5)
      )
      @bottomGeometry.faces.push(new THREE.Face3(0, 1, 2))
      @bottomGeometry.faces.push(new THREE.Face3(1, 2, 3))
      @bottomMesh = new THREE.Mesh(@bottomGeometry, Water.bottomMaterial)
      scene.add(@bottomMesh)

      # side
      @sideGeometries = []

      # side1
      geo = new THREE.Geometry()
      @sideGeometries.push(geo)
      bone = _.first(@bones)
      for n in [0 ... bone.length]
        b1 = bone[n].position().clone()
        b1.y = -0.5
        geo.vertices.push(
          bone[n    ].position(),
          b1,
        )
        if bone[n + 1] isnt undefined
          geo.faces.push(new THREE.Face3(n * 2    , n * 2 + 1, n * 2 + 2))
          geo.faces.push(new THREE.Face3(n * 2 + 1, n * 2 + 2, n * 2 + 3))

      mesh = new THREE.Mesh(geo, Water.sideMaterial)
      scene.add(mesh)

      # side2
      geo = new THREE.Geometry()
      @sideGeometries.push(geo)
      bone = _.last(@bones)
      for n in [0 ... bone.length]
        b1 = bone[n].position().clone()
        b1.y = -0.5
        geo.vertices.push(
          bone[n    ].position(),
          b1,
        )
        if bone[n + 1] isnt undefined
          geo.faces.push(new THREE.Face3(n * 2    , n * 2 + 1, n * 2 + 2))
          geo.faces.push(new THREE.Face3(n * 2 + 1, n * 2 + 2, n * 2 + 3))

      mesh = new THREE.Mesh(geo, Water.sideMaterial)
      scene.add(mesh)

      # side3
      geo = new THREE.Geometry()
      @sideGeometries.push(geo)
      for n in [0 ... @bones.length]
        bone = @bones[n]
        b1 = _.first(bone).position().clone()
        b1.y = -0.5
        geo.vertices.push(
          _.first(bone).position(),
          b1,
        )
        if @bones[n + 1] isnt undefined
          geo.faces.push(new THREE.Face3(n * 2    , n * 2 + 1, n * 2 + 2))
          geo.faces.push(new THREE.Face3(n * 2 + 1, n * 2 + 2, n * 2 + 3))

      mesh = new THREE.Mesh(geo, Water.sideMaterial)
      scene.add(mesh)

      # side4
      geo = new THREE.Geometry()
      @sideGeometries.push(geo)
      for n in [0 ... @bones.length]
        bone = @bones[n]
        b1 = _.last(bone).position().clone()
        b1.y = -0.5
        geo.vertices.push(
          _.last(bone).position(),
          b1,
        )
        if @bones[n + 1] isnt undefined
          geo.faces.push(new THREE.Face3(n * 2    , n * 2 + 1, n * 2 + 2))
          geo.faces.push(new THREE.Face3(n * 2 + 1, n * 2 + 2, n * 2 + 3))

      mesh = new THREE.Mesh(geo, Water.sideMaterial)
      scene.add(mesh)


    update: ->
      work = for line in @bones
        for w in line
          x: w.position().x
          y: w.position().y
          z: w.position().z

      f = 0.01
      sub = new THREE.Vector3()
      for d, x in @bones
        for d, z in @bones[x]
          self = @bones[x][z]
          neighbors = [
            [x    , z - 1],
            [x - 1, z - 1],
            [x - 1, z    ],
            [x    , z + 1],
            [x + 1, z    ],
            [x + 1, z - 1],
          ]
          for [px, pz] in neighbors
            if work[px] isnt undefined and work[px][pz] isnt undefined
              d = (work[px][pz].y - self.position().y) * f
              self.speed.y += d
          self.speed.y += (x * 0.0 - self.position().y) * f
          self.speed.multiplyScalar(0.92)
          self.position().add(self.speed)
      @surfaceGeometry.verticesNeedUpdate = true
      @surfaceGeometry.computeFaceNormals()
      for geo in @sideGeometries
        geo.verticesNeedUpdate = true

    shockIfBoundsChange: (p, power, nowInWater) ->
      for face in @surfaceGeometry.faces
        boneA = @bonesFlatten[face.a]
        boneB = @bonesFlatten[face.b]
        boneC = @bonesFlatten[face.c]
        v_a = boneA.position()
        v_b = boneB.position()
        v_c = boneC.position()
        v_p = p

        # caluculate cross product
        ab_x = (v_b.x - v_a.x)
        ab_z = (v_b.z - v_a.z)
        bp_x = (v_p.x - v_b.x)
        bp_z = (v_p.z - v_b.z)

        bc_x = (v_c.x - v_b.x)
        bc_z = (v_c.z - v_b.z)
        cp_x = (v_p.x - v_c.x)
        cp_z = (v_p.z - v_c.z)

        ca_x = (v_a.x - v_c.x)
        ca_z = (v_a.z - v_c.z)
        ap_x = (v_p.x - v_a.x)
        ap_z = (v_p.z - v_a.z)

        c1 = ab_x * bp_z - ab_z * bp_x
        c2 = bc_x * cp_z - bc_z * cp_x
        c3 = ca_x * ap_z - ca_z * ap_x

        # given point is out of range
        unless (c1 > 0 and c2 > 0 and c3 > 0) or (c1 < 0 and c2 < 0 and c3 < 0)
          continue

        # calculate inner product, (toward center of face from the object  and face normal vector)
        face.color = new THREE.Color(0xff0000)
        center = new THREE.Vector3(0, 0, 0)
        center.add(v_a)
        center.add(v_b)
        center.add(v_c)
        center.multiplyScalar(1.0 / 3.0)
        cp = center
        cp.sub(p)

        inWater = face.normal.dot(cp) > 0

        if inWater isnt nowInWater
          f = 0.8
          boneA.speed.y += power * f
          boneB.speed.y += power * f
          boneC.speed.y += power * f

        return inWater


  class Ika
    class BackBone
      constructor: (@index, p) ->
        @position = new THREE.Vector3(p.x, p.y, p.z)
        @upAxis = new THREE.Vector3(0, 1, 0)
        @sideAxis = new THREE.Vector3(1, 0, 0)

    constructor: (scene) ->
      @count = 0
      m = 12
      # make backbone
      p = 
        x: Math.random() * World.size * 2 - World.size
        y:-Math.random() * World.size
        z: Math.random() * World.size * 2 - World.size
      @backBones = for index in [0 ... m]
        new BackBone(index, p)
      @inWater = p.y < 0


      # create full vertices
      @vertices = for i in [0 ... m * 3]
        new THREE.Vector3()

      @surfaceGeometry = new THREE.Geometry()
      # set three vertices per bone (left side, middle backbone, and right side)
      for v in @vertices
        @surfaceGeometry.vertices.push(
          v
        )

      # and set polygon coordinates
      for i in [0 ... (@surfaceGeometry.vertices.length / 3) - 1]
       x = i * 3
       @surfaceGeometry.faces.push(
         new THREE.Face3(x    , x + 1, x + 3),
         new THREE.Face3(x + 3, x + 1, x + 4),
         new THREE.Face3(x + 2, x + 1, x + 5),
         new THREE.Face3(x + 4, x + 1, x + 5)
       )

      @surfaceMaterial = new THREE.MeshBasicMaterial
        color: 0x111155
        transparent: true
        depthTest: false
        blending: THREE.AdditiveBlending
        side: THREE.DoubleSide

      @surfaceMesh = new THREE.Mesh(@surfaceGeometry, @surfaceMaterial)
      scene.add(@surfaceMesh)

      # set outline vertices
      @outlineGeometry = new THREE.Geometry()
      for i in [0 ... m]
        @outlineGeometry.vertices.push(@vertices[i * 3])
      for i in [m - 1 .. 0]
        @outlineGeometry.vertices.push(@vertices[i * 3 + 2])

      @outlineMaterial = new THREE.LineBasicMaterial
        color: 0x222222
        depthTest: false
        transparent: true
        blending: THREE.AdditiveBlending
        side: THREE.DoubleSide

      @outlineMesh = new THREE.Line(@outlineGeometry, @outlineMaterial)
      scene.add(@outlineMesh)

      # make vector for control
      @eyeAxis = new THREE.Vector3(0, 0, -1)
      @headAxis = new THREE.Vector3(0, 1, 0)
      @handAxis = new THREE.Vector3()
      @handAxis.crossVectors(@eyeAxis, @headAxis)

      @speed = new THREE.Vector3(0, 0, 0)

    id: (@_id=@_id) -> @_id

    isSelf: (that) ->
      this.id() is that.id()

    position: ->
      @backBones[0].position

    direction: ->
      @eyeAxis

    update: ->
      if @inWater
        intention = new THREE.Vector3(0, 0, 0)

        # detect nearest or visible other aggregate
        nearestOne = null
        nearestSq = Number.MAX_VALUE
        others = []

        alignment = new THREE.Vector3(0, 0, 0)
        center = new THREE.Vector3(0, 0, 0)

        for that in IkaAggregate.all()
          unless this.isSelf(that)
            sub = new THREE.Vector3()
            sub.subVectors(@position(), that.position())
            sq = sub.lengthSq()
            if sq < nearestSq
              nearestSq = sq
              nearestOne = that
            # near and range of perspective
            if that.inWater and sq < 0.03 and @direction().dot(sub) > 0
              others.push(that)
              alignment.add(that.direction())
              center.add(that.position())

        # separation
        idealDist = 0.02
        actualDist = Math.sqrt(nearestSq)
        if actualDist < idealDist * 2
          sub = new THREE.Vector3()
          sub.subVectors(nearestOne.position(), @position())
          f = (actualDist - idealDist) / idealDist * 1.0
          sub.normalize()
          sub.multiplyScalar(f)
          separation = sub
          intention.add(sub)

        if others.length > 0
          # alignment
          alignment.normalize()
          alignment.multiplyScalar(0.025)
          intention.add(alignment)

          # cohesion (calculate center of aggregate)
          center.multiplyScalar(1.0 / others.length)
          # obtain a vector for itself to center
          sub = new THREE.Vector3()
          sub.subVectors(center, @position())
          sub.normalize()
          sub.multiplyScalar(0.04)
          cohesion = sub
          intention.add(cohesion)

        # avoid wall collision
        f = 0.10
        intention.x -= Math.sin(@position().x) * f
        intention.y -= Math.sin(@position().y) * f
        intention.z -= Math.sin(@position().z) * f

        # swing
        uc = @headAxis.clone()
        uc.multiplyScalar(Math.sin(@count * 0.1) * 0.1)
        intention.add(uc)

        sub = new THREE.Vector3()
        sub = intention.normalize()

        handDot = @handAxis.dot(sub)

        # convert vector sub -> unit vector
        sub.normalize()
        # and multiply
        sub.multiplyScalar(0.00013)
        @speed.add(sub)
        # speed down
        @speed.multiplyScalar(0.9990)

      unless @inWater
        @speed.add(new THREE.Vector3(0, -0.00015, 0))
        @speed.multiplyScalar(0.999)

        handDot = 0


      # ika would like to up
      @eyeAxis.copy(@speed)
      @eyeAxis.normalize()
      @headAxis.applyAxisAngle(@eyeAxis, handDot * 0.1)
      # update hand axis
      @handAxis.crossVectors(@eyeAxis, @headAxis)

      # backbone control (copy n - 1th bone to nth one continually)
      for n in [@backBones.length - 1 .. 1]
        @backBones[n].position.copy(@backBones[n - 1].position)
        @backBones[n].sideAxis.copy(@backBones[n - 1].sideAxis)
        @backBones[n].upAxis.copy(@backBones[n - 1].upAxis)

      @backBones[0].position.add(@speed)
      @backBones[0].sideAxis.copy(@handAxis)
      @backBones[0].upAxis.copy(@headAxis)

      # hit test with wall of the world
      p = @position()
      for prop in ['x', 'y', 'z']
        if p[prop] < -World.size
          @speed[prop] = Math.abs(@speed[prop]) * 0.9
        else if p[prop] > World.size
          @speed[prop] =-Math.abs(@speed[prop]) * 0.9

      # make shape
      for backBone in @backBones
        i = backBone.index
        x = if i < 4
          i * 2.0
        else if i < 8
          (i - 2) * 0.8
        else
          0.1

        p = backBone.position
        v = backBone.sideAxis.clone()
        v.multiplyScalar(x * 0.0007)

        u = backBone.upAxis.clone()
        u.multiplyScalar(Math.sin(i * 0.5 + @count * 0.2) * (12 - i) * -0.0003)

        @vertices[i * 3 + 0].set(p.x + v.x + u.x, p.y + v.y + u.y, p.z + v.z + u.z)
        @vertices[i * 3 + 1].set(p.x            , p.y            , p.z            )
        @vertices[i * 3 + 2].set(p.x - v.x + u.x, p.y - v.y + u.y, p.z - v.z + u.z)

      # hit test with water
      prevInWater = @inWater
      @inWater = water.shockIfBoundsChange(@position(), @speed.y, @inWater)
      if prevInWater isnt @inWater
        @speed.y *= 0.95

      @surfaceGeometry.verticesNeedUpdate = true
      @outlineGeometry.verticesNeedUpdate = true

      @count++

  class IkaAggregate
    @_ikas: []
    @_id:  0
    @register: (ika) ->
      IkaAggregate._ikas.push(ika)
      ika.id(IkaAggregate.numberingId())
    @numberingId: ->
      ++IkaAggregate._id
    @all: -> IkaAggregate._ikas


  class CameraControll
    constructor: (@camera) ->
      @count = ~~(65536 * Math.random())
      @cameraWorks = []
      @cameraWorks.push =>
        =>
          @camera.up.set(0, 1, 0)
          @camera.position.set(Math.cos(@count * 0.0021) * 0.7, -Math.sin(@count * 0.0012) * 0.5, Math.sin(@count * 0.005) * 0.5)
          @camera.lookAt(new THREE.Vector3(0, 0, 0))
      @cameraWorks.push =>
        maxDist = 0.2
        target = _.sample(IkaAggregate.all())
        =>
          sub = target.position().clone()
          sub.sub(@camera.position)
          len = sub.length()
          if len > maxDist
            sub.multiplyScalar(0.01)
            @camera.position.add(sub)

          @camera.up.set(0, 1, 0)
          @camera.lookAt(target.position())
      @cameraWorks.push =>
        target = _.sample(IkaAggregate.all())
        =>
          @camera.up.copy(target.headAxis)
          @camera.position.copy(target.position())
          v = target.position().clone()
          v.add(target.eyeAxis)
          @camera.lookAt(v)
      @switch(0)
    switch: (n) ->
      if n isnt undefined
        @cameraWork = @cameraWorks[n]()
      else
        @cameraWork = _.sample(@cameraWorks)()
    update: ->
      @cameraWork.call()
      @count++


  # initialize
  World.setup(scene)
  water = new Water(scene)

  for i in [0 .. 128]
    ika = new Ika(scene)
    IkaAggregate.register(ika)

  cameraCtl = new CameraControll(camera)
  renderer.domElement.addEventListener 'click', ->
    cameraCtl.switch()

  render = ->
  
    for ika in IkaAggregate.all()
      ika.update()

    water.update()

    cameraCtl.update()
    requestAnimationFrame(render)
    renderer.render(scene, camera)

  
  render()

window.ikaMain = ikaMain
