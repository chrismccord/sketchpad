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
    this.pad          = new Sketchpad(this.el, window.userId)

    this.padChannel.join().receive("ok", ({data}) => {
      this.pad.loadJSON(data)
      this.pad.redraw()
    })
    this.bind()
  },

  bind(){
    this.pad.on("stroke", data => this.padChannel.push("stroke", data) )

    this.padChannel.on("presence_state", state => {
      this.presences = Presence.syncState(this.presences, state)
      this.renderUsers()
    })
    this.padChannel.on("presence_diff", diff => {
      this.presences = Presence.syncDiff(this.presences, diff,
                                         this.onPresenceJoin.bind(this),
                                         this.onPresenceLeave.bind(this))
      this.renderUsers()
    })

    this.padChannel.on("pad_request", () => {
      console.log("got pad request from server")
      this.padChannel.push("pad_png", {img: this.pad.getImageURL()})
    })

    this.padChannel.on("stroke", ({user_id, stroke}) => {
      this.pad.putStroke(user_id, stroke, {color: "#000000"})
    })

    this.clearButton.addEventListener("click", (e) => {
      this.padChannel.push("clear")
    })

    this.exportButton.addEventListener("click", (e) => {
      window.open(this.pad.getImageURL())
    })

    this.padChannel.on("clear", () => this.pad.clear())

    this.padChannel.on("new_msg", ({body: body, user_id: userId}) => {
      this.msgContainer.innerHTML += `<br/><b>${sanitize(userId)}</b>: ${sanitize(body)}`
      this.msgContainer.scrollTop = this.msgContainer.scrollHeight
    })

    this.msgInput.addEventListener("keypress", e => {
      if(e.keyCode !== 13){ return }

      let onOk = () => {
        this.msgInput.value = ""
        this.msgInput.disabled = false
      }
      let onError = () => { this.msgInput.disabled = false }

      e.preventDefault()
      this.msgInput.disabled = true
      this.padChannel.push("publish_msg", {body: this.msgInput.value})
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