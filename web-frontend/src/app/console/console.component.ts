import { Component, ElementRef, AfterViewInit, Renderer2 } from '@angular/core';
import {MatButtonModule} from '@angular/material/button';
// @ts-expect-error no types
import RFB from '@novnc/novnc/lib/rfb';

// TODO, see following issue
// https://github.com/novnc/noVNC/pull/1944
// https://github.com/novnc/noVNC/issues/1943

@Component({
  selector: 'app-console',
  imports: [MatButtonModule],
  templateUrl: './console.component.html',
  styleUrl: './console.component.scss'
})
export class ConsoleComponent implements AfterViewInit {
  title = "vnc-client";

  public rfb: any;

  constructor(private el: ElementRef, private renderer: Renderer2) {}

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
    const container: HTMLElement | null = document.getElementById('vnc-screen');
    if (container) {
      // Creating a new RFB object will start a new connection
      if (this.rfb === undefined) {
        console.log("Connect to qemu");
        this.rfb = new RFB(container, "ws://127.0.0.1:5700");
        this.rfb.scaleViewport = true;
      }
      else {
        console.log("Already connected to qemu, so reconnect");
        this.rfb.disconnect();
        this.rfb = new RFB(container, "ws://127.0.0.1:5700");
        this.rfb.scaleViewport = true;
      }
    }
  }
}
