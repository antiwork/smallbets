import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Connects to data-controller="bridge--button"
export default class extends BridgeComponent {
  static component = "button"

  connect() {
    super.connect()

    const title = this.bridgeElement.bridgeAttribute("title")
    this.send("connect", {title}, () => {
      this.bridgeElement.click();
    });
  }

  disconnect() {
    super.disconnect()

    this.send("disconnect");
  }
}
