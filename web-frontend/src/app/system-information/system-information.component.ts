import { Component } from '@angular/core';
import { BackendCommunicationService } from '../backend-communication.service';


@Component({
  selector: 'app-system-information',
  templateUrl: './system-information.component.html',
  styleUrl: './system-information.component.scss',
  imports: []
})
export class SystemInformationComponent {
  containerInfo?: string;

  constructor(private service: BackendCommunicationService) {
    this.service.getContainerInfo().subscribe(response => {
      this.containerInfo = response;
    })
  }

}
