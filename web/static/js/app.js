import "phoenix_html"
import {Socket, Presence} from "phoenix"
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
    this.usersContainer = document.getElementById("users")
    this.presences    = {}

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

    padChannel.on("presence_state", state => {
      this.presences = Presence.syncState(this.presences, state)
      this.renderUsers()
    })
    padChannel.on("presence_diff", diff => {
      this.presences = Presence.syncDiff(this.presences, diff,
                                         this.onPresenceJoin.bind(this),
                                         this.onPresenceLeave.bind(this))
      this.renderUsers()
    })

    padChannel.on("pad_request", () => {
      console.log("got pad request from server")
      padChannel.push("pad_png", {img: pad.getImageURL()})
    })

    padChannel.on("stroke", ({user_id, stroke}) => {
      pad.putStroke(user_id, stroke, {color: "#000000"})
    })

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

  },

  onPresenceJoin(id, current, newPres){
    if(!current){
      console.log("user has entered for the first time", id)
    } else {
      console.log("user additional presence", id)
    }
  },

  onPresenceLeave(id, current, leftPres){
    if(current.metas.length === 0){
      console.log("user has left from all devices", leftPres)
    } else {
      console.log("user has left from a devices", leftPres)
    }
  },

  renderUsers(){
    let listBy = (id, {metas: [first, ...rest]}) => {
      first.count = rest.length + 1 // count of this user's presences
      first.id = id
      return first
    }

    this.usersContainer.innerHTML = Presence.list(this.presences, listBy).map(user => {
      return `<br/>${sanitize(user.id)} (${sanitize(user.count)})`
    }).join("")
  }
}

App.init(window.userToken)