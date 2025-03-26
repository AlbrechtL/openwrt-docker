import { Component, ElementRef, AfterViewInit, Renderer2 } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';

// @ts-expect-error no types
import RFB from '@novnc/novnc/lib/rfb';

import { BackendCommunicationService } from '../backend-communication.service';


// TODO, see following issue
// https://github.com/novnc/noVNC/pull/1944
// https://github.com/novnc/noVNC/issues/1943

@Component({
  selector: 'app-console',
  imports: [
    MatMenuModule,
    MatIconModule,
    MatButtonModule,
    MatCardModule
  ],
  templateUrl: './console.component.html',
  styleUrl: './console.component.scss'
})
export class ConsoleComponent implements AfterViewInit {
  title = "vnc-client";

  public rfb: any;

  constructor(private el: ElementRef, private renderer: Renderer2, private service: BackendCommunicationService) { }

  ngAfterViewInit(): void {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.startClient();
        }
      });
    }, { threshold: 0.1 });

    observer.observe(this.el.nativeElement);
  }

  startClient() {
    // Read parameters specified in the URL query string
    // By default, use the host and port of server that served this file
    const host = window.location.hostname;
    const port = window.location.port;
    const path = "websockify";
    // Build the websocket URL used to connect
    let url = "ws";

    if (window.location.protocol === "https:") {
      url = "wss";
    } else {
      url = "ws";
    }

    url += "://" + host;
    if (port) {
      url += ":" + port;
    }
    url += "/" + path;

    //url = "ws://localhost:8006/websockify" // Just for development

    console.log("URL: ", url);

    const container: HTMLElement | null = document.getElementById('vnc-screen');
    if (container) {
      // Creating a new RFB object will start a new connection
      if (this.rfb === undefined) {
        console.log("Connect to qemu");
        this.rfb = new RFB(container, url);
        this.rfb.scaleViewport = true;
        this.rfb.background = "unset";
        this.rfb.showDotCursor = true;
      }
      else {
        console.log("Already connected to qemu, so reconnect");
        this.rfb.disconnect();
        this.rfb = new RFB(container, url);
        this.rfb.scaleViewport = true;
        this.rfb.background = "unset";
        this.rfb.showDotCursor = true;
      }
    }
  }

  rebootOpenWrt() {
    this.service.gracefulReboot().subscribe();
  }
}
