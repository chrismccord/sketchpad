// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

import {Socket} from "phoenix"
import Sketchpad from "./sketchpad"

let userId = Math.random() * 100
let socket = new Socket("/socket")
socket.connect()

let padChannel = socket.channel("pad:lobby")
let ocrContainer = document.getElementById("ocr")


let el = document.getElementById('sketchpad');
let pad = new Sketchpad(el, {
  samplePoints: 5,
  line: {
    //color: '#f44335',
    color: '#000000',
    size: 5
  }
});
pad.on("stroke", data => padChannel.push("stroke", data))
window.pad = pad

padChannel.on("stroke", (data) => {
  console.log("stroke", data)
  pad.putStroke(userId, data, {color: '#000000'})
})

setInterval(() => {
  padChannel.push("ocr", {img: pad.getImageURL()})
}, 5000)

padChannel.on("ocr", ({text}) => ocrContainer.innerHTML = text )
padChannel.join()
