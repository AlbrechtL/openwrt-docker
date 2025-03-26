import { Component, inject } from '@angular/core';
import { MatGridListModule } from '@angular/material/grid-list';
import { MatMenuModule } from '@angular/material/menu';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatListModule } from '@angular/material/list';
import { BackendCommunicationService } from '../backend-communication.service';


@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
  standalone: true,
  imports: [
    MatGridListModule,
    MatMenuModule,
    MatIconModule,
    MatButtonModule,
    MatCardModule,
    MatProgressSpinnerModule,
    MatListModule
  ]
})
export class DashboardComponent {
  openwrtVersion?: string;
  openWrtKernel?: string;

  wan?: string;
  lan?: string;
  usb?: string[];
  pci?: string[];

  constructor(private service: BackendCommunicationService) {
    this.service.pollOpenWrtInfo().subscribe(response => {
      this.openwrtVersion = response.version;
      this.openWrtKernel = response.kernelVersion;
    });

    this.service.getAttachedHardware().subscribe(response => {
      this.wan = response.wan;
      this.lan = response.lan;
      this.usb = response.usb;
      this.pci = response.pci;
    });
  }
}
