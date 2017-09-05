import "phoenix_html"
import {Socket, Presence} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"
import socket from "./socket"


socket.connect()

let App = {
  init(){
    this.presences = {}
    this.padChannel = socket.channel("pad:lobby")
    this.el = document.getElementById("sketchpad")
    this.pad = new Sketchpad(this.el, window.userId)
    this.clearButton = document.getElementById("clear-button")
    this.exportButton = document.getElementById("export-button")
    // chat
    this.msgInput = document.getElementById("message-input")
    this.msgContainer = document.getElementById("messages")
    // presence
    this.userList = document.getElementById("users")

    this.msgInput.addEventListener("keypress", e => {
      if(e.keyCode !== 13){ return }
      this.msgInput.disabled = true

      let onOk = () => {
        this.msgInput.value = ""
        this.msgInput.disabled = false
      }
      let onError = () => {
        this.msgInput.disabled = false
      }

      this.padChannel.push("new_message", {body: this.msgInput.value})
        .receive("ok", onOk)
        .receive("error", onError)
        .receive("timeout", onError)
    })


    this.padChannel.on("new_message", ({user_id, body}) => {
      this.msgContainer.innerHTML +=
        `<br/><b>${sanitize(user_id)}</b>: ${sanitize(body)}`
      this.msgContainer.scrollTop = this.msgContainer.scrollHeight
    })

    this.exportButton.addEventListener("click", e => {
      e.preventDefault()
      window.open(this.pad.getImageURL())
    })

    this.clearButton.addEventListener("click", e => {
      e.preventDefault()
      this.pad.clear()
      this.padChannel.push("clear")
    })

    this.padChannel.on("clear", () => this.pad.clear())

    this.pad.on("stroke", data => {
      this.padChannel.push("stroke", data)
    })

    this.padChannel.on("stroke", ({user_id, stroke}) => {
      this.pad.putStroke(user_id, stroke, {color: "#000000"})
    })

    this.padChannel.join()
      .receive("ok", resp => console.log("joined", resp))
      .receive("error", resp => console.log("failed to join", resp))


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

  },

  onPresenceJoin(id, current, newPres){
    if(!current){
      console.log(`${id} has joined for the first time`)
    } else {
      console.log(`${id} has joined from another device (or tab)`)
    }
  },

  onPresenceLeave(id, current, leftPres){
    if(current.metas.length === 0){
      console.log(`${id} has left the application`)
    } else {
      console.log(`${id} has closed a tab or device app`)
    }
  },

  renderUsers(){
    let listBy = (id, {metas: [first, ...rest]}) => {
      first.count = rest.length + 1
      first.username = id
      return first
    }

    let users = Presence.list(this.presences, listBy)
    this.userList.innerHTML = users.map(user => {
      return `<br/>${sanitize(user.username)} (${user.count})`
    }).join("")
  }


}

App.init()
