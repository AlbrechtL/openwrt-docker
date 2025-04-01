import { Component, AfterViewInit, OnDestroy } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

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
    MatCardModule,
    MatProgressSpinnerModule
  ],
  templateUrl: './console.component.html',
  styleUrl: './console.component.scss'
})
export class ConsoleComponent implements AfterViewInit, OnDestroy {
  title = "vnc-client";

  public rfb: any;
  vncConnected: boolean = false;
  private pollingInterval!: any;

  constructor(private service: BackendCommunicationService) {}

  ngAfterViewInit(): void {
    this.startClient();
    this.startPolling();
  }

  startPolling(): void {
    this.pollingInterval = setInterval(() => {
      //console.log('Checking vncConnected:', this.vncConnected);
      if (this.vncConnected === false) {
        this.startClient();
      }
    }, 5000);
  }

  startClient() {
    // TODO: Not ideal because it depends that the URL contains "console".
    // But I didn't find a way how to detect if the frontend runs behind a reverse proxy.
    let href = window.location.href;
    let url = href.replace(/console/gi, "websockify");

    // Just for development
    //url = "ws://localhost:8006/websockify"

    console.log("URL: ", url);

    const container: HTMLElement | null = document.getElementById('vnc-screen');
    if (container) {
      // Creating a new RFB object will start a new connection
      if (!this.vncConnected) {
        console.log("Connecting to qemu");
        this.connectNoVNC(container, url);
      }
      else {
        console.log("Already connected to qemu, so reconnect");
        this.rfb.disconnect();
        this.connectNoVNC(container, url);
      }
    }
  }

  connectNoVNC(container: HTMLElement, url: string) {
    this.rfb = new RFB(container, url);
    this.rfb.scaleViewport = true;
    this.rfb.background = "unset";
    this.rfb.showDotCursor = true;
    this.rfb.addEventListener('connect', () => {
      console.log("noVNC connect");
      this.vncConnected = true;
    });
    this.rfb.addEventListener('disconnect', () => {
      console.log("noVNC disconnect");
      this.vncConnected = false;
    });

  }

  rebootOpenWrt() {
    this.service.gracefulReboot().subscribe();
  }

  ngOnDestroy(): void {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }
}
