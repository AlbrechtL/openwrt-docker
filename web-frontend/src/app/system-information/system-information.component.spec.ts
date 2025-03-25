import { waitForAsync, ComponentFixture, TestBed } from '@angular/core/testing';

import { SystemInformationComponent } from './system-information.component';

describe('SystemInformationComponent', () => {
  let component: SystemInformationComponent;
  let fixture: ComponentFixture<SystemInformationComponent>;

  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
    }).compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(SystemInformationComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should compile', () => {
    expect(component).toBeTruthy();
  });
});
