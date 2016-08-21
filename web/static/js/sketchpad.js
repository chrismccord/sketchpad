
function map(obj, func){
  return Object.getOwnPropertyNames(obj).map(key => func(key, obj[key]))
}

function mergeObjects(obj1, obj2){
  var obj3 = {};
  var attrname;
  for (attrname in (obj1 || {})) {
    if (obj1.hasOwnProperty(attrname)) {
      obj3[attrname] = obj1[attrname];
    }
  }
  for (attrname in (obj2 || {})) {
    if (obj2.hasOwnProperty(attrname)) {
      obj3[attrname] = obj2[attrname];
    }
  }
  return obj3;
}


class Sketchpad {

  constructor(el, opts){
    if(!el){ throw new Error('Must pass in a container element') }

    this.opts = opts || {}
    this.opts.aspectRatio = this.opts.aspectRatio || 1
    this.opts.width = this.opts.width || el.clientWidth
    this.opts.height = this.opts.height || this.opts.width * this.opts.aspectRatio
    this.opts.samplePoints = this.opts.samplePoints || 10
    this.opts.line = mergeObjects({
      color: '#000',
      size: 5,
      cap: 'round',
      join: 'round',
      miterLimit: 10
    }, this.opts.line);

    this.users = {local: this.buildUser("local", this.opts.data)}
    this.events = {};
    this.undos = [];

    // Boolean indicating if currently drawing
    this.sketching = false;

    // Create a canvas element
    this.canvas = document.createElement('canvas');
    this.setCanvasSize(this.opts.width, this.opts.height);
    this.resizeTimer = null
    window.onresize = () => {
      clearTimeout(this.resizeTimer)
      this.resizeTimer = setTimeout(() => this.resize(el.clientWidth), 100)
    }
    el.appendChild(this.canvas);
    this.context = this.canvas.getContext('2d');
    // Event Listeners
    this.canvas.addEventListener('mousedown', e => this.startLine(e));
    this.canvas.addEventListener('touchstart', e => this.startLine(e));
    this.canvas.addEventListener('mousemove', e => this.moveLine(e));
    this.canvas.addEventListener('touchmove', e => this.moveLine(e));
    this.canvas.addEventListener('mouseup', e => this.endLine(e));
    this.canvas.addEventListener('mouseleave', e => this.endLine(e));
    this.canvas.addEventListener('touchend', e => this.endLine(e));
  }

  buildUser(userId, data){
    return data || {id: userId, strokes: [], lastPaintedIndex: 0}
  }

  setCanvasSize(width, height) {
    this.canvas.setAttribute('width', width);
    this.canvas.setAttribute('height', height);
    this.canvas.style.width = width + 'px';
    this.canvas.style.height = height + 'px';
  }

  getCanvasSize() {
    return({
      width: this.canvas.width,
      height: this.canvas.height
    })
  }

  // Returns a points x,y locations relative to the size of the canvase
  getPointRelativeToCanvas(point){
    let canvasSize = this.getCanvasSize();
    return({
      x: point.x / canvasSize.width,
      y: point.y / canvasSize.height
    });
  }

  isTouchEvent(e){ return e.type.indexOf('touch') !== -1 }

  getCursorRelativeToCanvas(e) {
    let cur = {};

    if (this.isTouchEvent(e)) {
      cur.x = e.touches[0].pageX - this.canvas.offsetLeft;
      cur.y = e.touches[0].pageY - this.canvas.offsetTop;
    } else {
      var rect = this.canvas.getBoundingClientRect();
      cur.x = e.clientX - rect.left;
      cur.y = e.clientY - rect.top;
    }

    return this.getPointRelativeToCanvas(cur);
  }

  getLineSizeRelativeToCanvas(size){
    let canvasSize = this.getCanvasSize();
    return size / canvasSize.width;
  }

  /**
   * Since points are stored relative to the size of the canvas
   * this takes a point and converts it to actual x, y distances in the canvas
  */
  normalizePoint(point){
    var canvasSize = this.getCanvasSize();
    return {
      x: point.x * canvasSize.width,
      y: point.y * canvasSize.height
    };
  }

  /**
   * Since line sizes are stored relative to the size of the canvas
   * this takes a line size and converts it to a line size
   * appropriate to the size of the canvas
  */
  normalizeLineSize(size){
    return size * this.getCanvasSize().width
  }

  // Draw a stroke on the canvas
  drawStroke(stroke) {
    this.context.beginPath();
    for (let j = 0; j < stroke.points.length - 1; j++) {
      let start = this.normalizePoint(stroke.points[j]);
      let end = this.normalizePoint(stroke.points[j + 1]);

      this.context.moveTo(start.x, start.y);
      this.context.lineTo(end.x, end.y);
    }
    this.context.closePath();

    this.context.strokeStyle = stroke.color;
    this.context.lineWidth = this.normalizeLineSize(stroke.size);
    this.context.lineJoin = stroke.join;
    this.context.lineCap = stroke.cap;
    this.context.miterLimit = stroke.miterLimit;

    this.context.stroke();
  }


  fullRedraw(){
    map(this.users, (id, user) => {
      user.lastPaintedIndex = 0
      this.redrawUser(user.id)
    })
  }

  redraw(){
    map(this.users, (id, user) => this.redrawUser(id))
  }

  redrawUser(userId){
    let user = this.users[userId]
    let {strokes, lastPaintedIndex} = user
    for(let i = lastPaintedIndex; i < strokes.length; i++) {
      this.drawStroke(strokes[i])
    }
    user.lastPaintedIndex = strokes.length - 1
  }

  // On mouse down, create a new stroke with a start location
  startLine(e){
    e.preventDefault();
    this.sketching = true;
    this.undos = [];

    let cursor = this.getCursorRelativeToCanvas(e);
    this.users["local"].strokes.push({
      points: [cursor],
      color: this.opts.line.color,
      size: this.getLineSizeRelativeToCanvas(this.opts.line.size),
      cap: this.opts.line.cap,
      join: this.opts.line.join,
      miterLimit: this.opts.line.miterLimit
    })
  }

  getEvents(event){ return this.events[event] || [] }

  moveLine(e){ if(!this.sketching){ return }
    e.preventDefault();

    let cursor = this.getCursorRelativeToCanvas(e)
    let point = {x: cursor.x, y: cursor.y}
    let lastStroke = this.lastStroke("local")
    let points = lastStroke.points
    points.push(point)
    this.redrawUser("local")
    if(points.length > this.opts.samplePoints){
      this.getEvents("stroke").forEach(cb => cb(lastStroke))
      this.startLine(e)
    }
  }

  lastStroke(userId){
    let strokes = this.users[userId].strokes
    return strokes[strokes.length - 1]
  }

  endLine(e){ if(!this.sketching){ return }
    e.preventDefault();

    this.sketching = false;
    let lastStroke = this.lastStroke("local")
    this.getEvents("stroke").forEach(cb => cb(lastStroke))

    // touchend events do not have a cursor position
    if(this.isTouchEvent(e)){ return }

    let cursor = this.getCursorRelativeToCanvas(e)
    lastStroke.points.push({x: cursor.x, y: cursor.y})
    this.redrawUser("local")
  }

  undo(){ if(this.strokes.local.length === 0){ return }
    this.undos.push(this.strokes.local.pop());
    this.redrawUser("local");
  }

  redo(){ if(this.undos.length === 0){ return }
    this.stroke.locals.push(this.undos.pop());
    this.redrawUser("local");
  }


  clear(){
    let canvasSize = this.getCanvasSize();
    this.undos = [];  // TODO: Add clear action to undo
    this.users = {local: this.buildUser("local", [])}
    this.lastStrokeIndex = 0
    this.context.clearRect(0, 0, canvasSize.width, canvasSize.height)
    this.redraw()
  }

  // Convert the sketchpad to a JSON object that can be loaded into
  // other sketchpads or stored on a server
  toJSON(){
    let canvasSize = this.getCanvasSize();
    return({
        version: 1,
        aspectRatio: canvasSize.width / canvasSize.height,
        strokes: {local: this.strokes}
    })
  }

  // Load a json object into the sketchpad
  // @return {object} - JSON object to load
  loadJSON(data){ this.strokes = data.strokes }

  // Get a static image element of the canvas
  getImage(){ return '<img src="' + this.getImageURL() + '"/>' }

  getImageURL(){ return this.canvas.toDataURL('image/png') }

  //Set the line size
  // @param {number} size - Size of the brush
  setLineSize(size){ this.opts.line.size = size }

  // Set the line color
  // @param {string} color - Hexadecimal color code
  setLineColor(color){ this.opts.line.color = color }

  // Draw a line
  // @param  {object} start    - Starting x and y locations
  // @param  {object} end      - Ending x and y locations
  // @param  {object} lineOpts - Options for line (color, size, etc.)
  drawLine(start, end, lineOpts){
    lineOpts = mergeObjects(this.opts.line, lineOpts);
    start = this.getPointRelativeToCanvas(start);
    end = this.getPointRelativeToCanvas(end);

    this.strokes.local.push({
      points: [start, end],
      color: lineOpts.color,
      size: this.getLineSizeRelativeToCanvas(lineOpts.size),
      cap: lineOpts.cap,
      join: lineOpts.join,
      miterLimit: lineOpts.miterLimit
    });
    this.redraw();
  }

  putStroke(userId, stroke, lineOpts){
    stroke = mergeObjects(stroke, lineOpts)
    if(!this.users[userId]){ this.users[userId] = this.buildUser(userId) }
    this.users[userId].strokes.push(stroke)
    this.redrawUser(userId)
  }

  // Resize the canvas maintaining original aspect ratio
  // @param  {number} width - New width of the canvas
  resize(width) {
    let height = width * this.opts.aspectRatio;
    this.opts.lineSize = this.opts.lineSize * (width / this.opts.width);
    this.opts.width = width;
    this.opts.height = height;

    this.setCanvasSize(width, height);
    this.fullRedraw();
  }

  on(event, callback){
    if(!this.events[event]){ this.events[event] = [] }
    this.events[event].push(callback)
  }
}




export default Sketchpad