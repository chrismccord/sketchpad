import css from "../css/app.css"
import "phoenix_html"
import {Socket, Presence} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"


let socket = new Socket("/socket", {
  params: {token: window.userToken},
  logger: function(kind, msg, data){
    console.log(`${kind}: ${msg}`, data)
  }
})

let App = {
  init(){
    socket.connect()
    this.padChannel = socket.channel("pad:lobby")
    this.el = document.getElementById("sketchpad")
    this.pad = new Sketchpad(this.el, window.username)

    // do stuff

    this.padChannel.on("tick", ({value}) => console.log("tick", value))

    this.padChannel.join()
      .receive("ok", resp => console.log("joined!", resp))
      .receive("error", resp => console.log("failed join", resp))
  }
}
if(window.userToken !== ""){ App.init() }
