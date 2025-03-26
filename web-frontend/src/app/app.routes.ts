import { Routes } from '@angular/router';
import { SystemInformationComponent } from "./system-information/system-information.component";
import { ConsoleComponent } from './console/console.component';
import { InfoComponent } from './info/info.component';
import { DashboardComponent } from './dashboard/dashboard.component';

export const routes: Routes = [
  { // Redirect to 'status' by default
    path: '',
    redirectTo: 'dashboard',
    pathMatch: 'full'
  },
  {
    path: 'dashboard',
    component: DashboardComponent,
    title: 'Dashboard'
  },
  {
    path: 'console',
    component: ConsoleComponent,
    title: 'Console'
  },
  {
    path: 'system_information',
    component: SystemInformationComponent,
    title: 'System information'
  },
  {
    path: 'info',
    component: InfoComponent,
    title: 'info'
  },
];
