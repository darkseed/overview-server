require [
  'apps/Tree/models/animator'
  'apps/Tree/models/property_interpolator'
  'apps/Tree/models/AnimatedFocus'
], (Animator, PropertyInterpolator, AnimatedFocus) ->
  # Not a unit test, because this is more useful
  describe 'models/animated_focus', ->
    describe 'AnimatedFocus', ->
      animator = undefined
      focus = undefined

      beforeEach ->
        interpolator = new PropertyInterpolator(1000, (x) -> x)
        animator = new Animator(interpolator)
        focus = new AnimatedFocus({ zoom: 0.5, pan: 0 }, { animator: animator })

      at = (ms, callback) -> Timecop.freeze(new Date(ms), callback)

      it 'should set target zoom and pan', ->
        at(0, -> focus.setPanAndZoom(0.25, 0.1))
        expect(focus.nextObject).toEqual({ pan: 0.25, zoom: 0.1 })

      it 'should allow setting time explicitly for animation', ->
        focus.animatePanAndZoom(0.25, 0.1, 500)
        focus.update(undefined, 1000)
        expect(focus.get('pan')).toEqual(0.125)

      it 'should clamp zoom above 0', ->
        focus.setPanAndZoom(0, 0)
        expect(focus.nextObject.zoom).toBeGreaterThan(0)

      it 'should clamp zoom to max 1', ->
        focus.setPanAndZoom(0, 1.2)
        expect(focus.nextObject.zoom).toEqual(1)

      it 'should clamp pan to 0 when zoom=1', ->
        focus.setPanAndZoom(-1, 1)
        expect(focus.nextObject.pan).toEqual(0)
        focus.setPanAndZoom(1, 1)
        expect(focus.nextObject.pan).toEqual(0)

      it 'should clamp pan to 0.375 when zoom=0.25', ->
        focus.setPanAndZoom(-1, 0.25)
        expect(focus.nextObject.pan).toEqual(-0.375)
        focus.setPanAndZoom(1, 0.25)
        expect(focus.nextObject.pan).toEqual(0.375)

      it 'should always clamp pan to 0.5 non-inclusive', ->
        focus.setPanAndZoom(0, -1)
        expect(focus.nextObject.pan).toBeGreaterThan(-0.5)
        focus.setPanAndZoom(0, 1)
        expect(focus.nextObject.pan).toBeLessThan(0.5)

      it 'should notify when zoom is set', ->
        spy = jasmine.createSpy()
        focus.on('change', spy)
        focus.setZoom(0.1)
        expect(spy).toHaveBeenCalled()

      it 'should notify when zoom animation starts', ->
        spy = jasmine.createSpy()
        focus.on('change', spy)
        focus.animateZoom(0.1)
        expect(spy).toHaveBeenCalled()

      it 'should notify when pan changes', ->
        spy = jasmine.createSpy()
        focus.on('change', spy)
        focus.setPan(0.25)
        expect(spy).toHaveBeenCalled()

      it 'should notify when pan animation starts', ->
        spy = jasmine.createSpy()
        focus.on('change', spy)
        focus.animatePan(0.1)
        expect(spy).toHaveBeenCalled()

      it 'should set needs_update=false', ->
        expect(focus.needsUpdate()).toBe(false)

      it 'should set needs_update=true when changing something', ->
        at(0, -> focus.animateZoom(0.1))
        expect(focus.needsUpdate()).toBe(true)

      it 'should keep needs_update=false when setting something', ->
        focus.setZoom(0.1)
        expect(focus.needsUpdate()).toBe(false)

      it 'should set needs_update=false when animation has finished', ->
        at(0, -> focus.animateZoom(0.1))
        at(1000, -> focus.update())
        expect(focus.needsUpdate()).toBe(false)