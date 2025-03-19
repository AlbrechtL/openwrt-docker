import { Component } from '@angular/core';
// @ts-expect-error no types
import RFB from '@novnc/novnc/lib/rfb';

// TODO, see following issue
// https://github.com/novnc/noVNC/pull/1944
// https://github.com/novnc/noVNC/issues/1943

@Component({
  selector: 'app-console',
  imports: [],
  templateUrl: './console.component.html',
  styleUrl: './console.component.scss'
})
export class ConsoleComponent {
  title = "vnc-client";

  public rfb: any;

  startClient() {
    console.log("Starting !!!");

    // Creating a new RFB object will start a new connection
    //this.rfb = new RFB(document.getElementById("screen"), url);
    const container: HTMLElement | null = document.getElementById('vnc-screen');
    if (container) {
      const rfb = new RFB(container, "ws://127.0.0.1:5700");
      //rfb.scaleViewport = true;
    }
  }
}
