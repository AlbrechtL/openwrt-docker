import { Component } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { BackendCommunicationService } from '../backend-communication.service';


@Component({
  selector: 'app-status',
  imports: [MatCardModule, MatButtonModule, MatProgressSpinnerModule],
  templateUrl: './status.component.html',
  styleUrl: './status.component.scss',
})
export class StatusComponent {
  openwrtVersion?: string;
  openWrtKernel?: string;

  constructor(private service: BackendCommunicationService) {
    this.service.pollOpenWrtInfo().subscribe(response => {
      this.openwrtVersion = response.version;
      this.openWrtKernel = response.kernelVersion;
    })
  }
}
