import { Routes } from '@angular/router';
import { SystemInformationComponent } from "./system-information/system-information.component";
import { StatusComponent } from './status/status.component';
import { ConsoleComponent } from './console/console.component';
import { InfoComponent } from './info/info.component';

export const routes: Routes = [
    {
    path: 'status',
    component: StatusComponent,
    title: 'Status'
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
