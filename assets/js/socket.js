import {Socket} from "phoenix"

let socket = new Socket("/socket", {
  params: {token: window.userToken},
  logger: (...args) => { console.log(...args) }
})

export default socket
