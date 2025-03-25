import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap, map } from 'rxjs';

interface OpenWrtInfo {
  version: string;
  kernelVersion: string;
}

@Injectable({
  providedIn: 'root'
})
export class BackendCommunicationService {
  //urlPrefix: string = 'http://localhost:8006'; // Just for development
  urlPrefix: string = '';

  constructor(private http: HttpClient) { }

  getOpenWrtInfo(): Observable<OpenWrtInfo> {
    return this.http.get<any>(this.urlPrefix + '/api/get_openwrt_info').pipe(
      tap(response => console.log('Fetched OpenWrt data:', response)),
      map(response => {
        let tmpVersion = 'Unknown';
        let tmpKernelVersion = 'Unknown';
        if (response['combined_output'] !== '\n') {
          try {
            response['combined_output'] = JSON.parse(response['combined_output']);

            tmpVersion = response['combined_output']['return']['pretty-name'];
            tmpKernelVersion = response['combined_output']['return']['kernel-release'];
          } catch (error) {
            //console.error('Error parsing combined_output:', error);
          }
        }
        return {
          version: tmpVersion,
          kernelVersion: tmpKernelVersion
        };
      })
    );
  }

  pollOpenWrtInfo(intervalMs: number = 1000): Observable<OpenWrtInfo> {
    return new Observable(observer => {
      const poll = () => {
        this.getOpenWrtInfo().subscribe({
          next: (response) => {
            if (response.version !== 'Unknown') {
              observer.next(response);
              observer.complete();
            } else {
              setTimeout(poll, intervalMs);
            }
          },
          error: (error) => {
            observer.error(error);
          }
        });
      };
      poll();
    });
  }

  gracefulReboot(): Observable<any> {
    return this.http.get(this.urlPrefix + '/api/reboot');
  }

  getContainerInfo(): Observable<any> {
    return this.http.get<any>(this.urlPrefix + '/api/get_container_info').pipe(
      map(response => {
        return response['combined_output'];
      })
    );
  }
}
