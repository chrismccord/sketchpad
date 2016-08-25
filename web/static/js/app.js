import "phoenix_html"
import {Socket} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"

let App = {
  init(userToken){ if(!userToken){ return }
    this.socket = new Socket("/socket", {params: {token: window.userToken}})
    this.socket.connect()

    this.padChannel   = this.socket.channel("pad:lobby")
    this.clearButton  = document.getElementById("clear-button")
    this.exportButton = document.getElementById("export-button")
    this.msgContainer = document.getElementById("messages")
    this.msgInput     = document.getElementById("message-input")
    this.el           = document.getElementById("sketchpad")

    this.padChannel.join()
      .receive("ok", ({user_id, data}) => this.onJoin(user_id, data))
  },

  onJoin(userId, padData){
    let {
      padChannel,
      exportButton,
      clearButton,
      el,
      msgInput,
      msgContainer
    } = this
    console.log("rendering...", padData)

    let pad = new Sketchpad(el, userId, {data: padData})

    pad.on("stroke", data => padChannel.push("stroke", data) )

    padChannel.on("stroke", ({user_id, stroke}) => {
      pad.putStroke(user_id, stroke, {color: "#000000"})
    })

    setInterval(() => {
      padChannel.push("ocr", {img: pad.getImageURL()})
    }, 5000)

    clearButton.addEventListener("click", (e) => {
      padChannel.push("clear")
    })

    exportButton.addEventListener("click", (e) => {
      window.open(pad.getImageURL())
    })

    padChannel.on("clear", () => pad.clear())

    padChannel.on("new_msg", ({body: body, user_id: userId}) => {
      msgContainer.innerHTML += `<br/><b>${sanitize(userId)}</b>: ${sanitize(body)}`
      msgContainer.scrollTop = msgContainer.scrollHeight
    })

    msgInput.addEventListener("keypress", e => {
      if(e.keyCode !== 13){ return }

      let onOk = () => {
        msgInput.value = ""
        msgInput.disabled = false
      }
      let onError = () => { msgInput.disabled = false }

      e.preventDefault()
      msgInput.disabled = true
      padChannel.push("publish_msg", {body: msgInput.value})
        .receive("ok", onOk)
        .receive("error", onError)
        .receive("timeout", onError)
    })

  }
}

App.init(window.userToken)