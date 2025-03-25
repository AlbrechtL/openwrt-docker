import { TestBed } from '@angular/core/testing';

import { BackendCommunicationService } from './backend-communication.service';

describe('BackendCommunicationService', () => {
  let service: BackendCommunicationService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(BackendCommunicationService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
