import { Component, ChangeDetectionStrategy } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { MatToolbarModule} from '@angular/material/toolbar';
import { SideNavigationComponent } from "./side-navigation/side-navigation.component";


@Component({
  selector: 'app-root',
  imports: [
    RouterOutlet,
    SideNavigationComponent,
    MatToolbarModule
],
  templateUrl: './app.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './app.component.scss'
})
export class AppComponent {
  title = 'openwrt-docker-web-gui';
}
