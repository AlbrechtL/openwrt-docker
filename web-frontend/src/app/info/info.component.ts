import { Component, ChangeDetectionStrategy, inject } from '@angular/core';
import { MatDividerModule } from '@angular/material/divider';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { BackendCommunicationService } from '../backend-communication.service';


@Component({
  selector: 'app-info',
  imports: [MatListModule, MatDividerModule, MatIconModule, MatDialogModule],
  templateUrl: './info.component.html',
  styleUrl: './info.component.scss'
})
export class InfoComponent {
  readonly dialog = inject(MatDialog);
  openWrtVersion?: string;
  containerBuildDate?: string;

  constructor(private service: BackendCommunicationService) {
    this.service.getVersion().subscribe(response => {
      this.openWrtVersion = response.openWrtVersion;
      this.containerBuildDate = response.containerBuildDate;
    });
  }

  openLicenseDialog() {
    const dialogRef = this.dialog.open(DialogContentLicenseDialog);

    dialogRef.afterClosed().subscribe(result => {
      console.log(`Dialog result: ${result}`);
    });
  }
}

@Component({
  selector: 'dialog-content-license-dialog',
  templateUrl: 'license-dialog.html',
  imports: [MatDialogModule, MatButtonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DialogContentLicenseDialog {}
