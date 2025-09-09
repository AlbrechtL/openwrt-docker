import { Component, inject } from '@angular/core';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { AsyncPipe } from '@angular/common';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule} from '@angular/material/tooltip';
import { Observable } from 'rxjs';
import { map, shareReplay } from 'rxjs/operators';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { RouterOutlet, RouterModule } from '@angular/router';
import { BackendCommunicationService } from '../backend-communication.service';


@Component({
  selector: 'app-side-navigation',
  templateUrl: './side-navigation.component.html',
  styleUrl: './side-navigation.component.scss',
  standalone: true,
  imports: [
    MatToolbarModule,
    MatButtonModule,
    MatSidenavModule,
    MatListModule,
    MatIconModule,
    AsyncPipe,
    MatSlideToggleModule,
    RouterOutlet,
    RouterModule,
    MatTooltipModule,
  ]
})
export class SideNavigationComponent {
  LuciButtonText: string = "OpenWrt LuCI web interface";
  LuciButtonUrl: string = "https://" + window.location.hostname + ":9000"; // ToDo make port 9000 configurable
  LuciButtonTooltip: string = 'Requirements: LAN="veth", FORWARD_LUCI="true", \
        default OpenWrt DHCP LAN settings, \
        configured "env-openwrt0" Ethernet interface in host system. \
        Internally a reverse proxy is forwarding the web interface from "host-ip:9000" to "172.31.1.1:80"';

  private breakpointObserver = inject(BreakpointObserver);

  constructor(private service: BackendCommunicationService) {
    this.service.getLuciButtonJson().subscribe(response => {
      let LuciButtonJson = response;

      if(LuciButtonJson.trim() != "") {
        try {
          let LuciButtonJson = JSON.parse(response);
          this.LuciButtonText = LuciButtonJson.name;
          this.LuciButtonUrl = LuciButtonJson.url;
          this.LuciButtonTooltip = LuciButtonJson.tooltip;
        }
        catch(error) {
          this.LuciButtonText = "JSON error";
          this.LuciButtonUrl = "";
          this.LuciButtonTooltip = `${error}`;
        }
      }
    });
  }

  isHandset$: Observable<boolean> = this.breakpointObserver.observe(Breakpoints.Handset)
    .pipe(
      map(result => result.matches),
      shareReplay()
    );

  openLuCI() {
    console.log("LuCI URL: ", this.LuciButtonUrl);
    window.open(this.LuciButtonUrl, "_blank");
  }
}
