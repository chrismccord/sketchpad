import "phoenix_html"
import {Socket} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"

let App = {
  init(userId, token){ if(!token){ return }
    let socket = new Socket("/socket", {
      params: {token: token}
    })
    this.sketchpadContainer = document.getElementById("sketchpad")
    this.pad = new Sketchpad(this.sketchpadContainer, userId)
    // socket.connect()
    window.socket = socket

    this.padChannel = socket.channel("pad:lobby")
    this.padChannel.join()
      .receive("ok", resp => console.log("joined!", resp) )
      .receive("error", resp => console.log("join failed!", resp) )
  }
}
App.init(window.userId, window.userToken)
