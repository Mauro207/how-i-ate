import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { marked } from 'marked';
import { firstValueFrom } from 'rxjs';
import { NavigationComponent } from '../navigation/navigation.component';

interface UpdateFile {
  title: string;
  file: string;
}

interface UpdatesIndex {
  files: UpdateFile[];
}

@Component({
  selector: 'app-updates',
  standalone: true,
  imports: [CommonModule, NavigationComponent],
  templateUrl: './updates.component.html',
  styleUrl: './updates.component.css'
})
export class UpdatesComponent implements OnInit {
  private readonly http = inject(HttpClient);

  files = signal<UpdateFile[]>([]);
  selectedFile = signal<UpdateFile | null>(null);
  renderedHtml = signal('');
  loadingIndex = signal(true);
  loadingMarkdown = signal(false);
  errorMessage = signal('');

  ngOnInit(): void {
    void this.loadUpdatesIndex();
  }

  async selectUpdateFile(file: UpdateFile): Promise<void> {
    this.selectedFile.set(file);
    this.loadingMarkdown.set(true);
    this.errorMessage.set('');

    try {
      const markdown = await firstValueFrom(this.http.get(`/updates/${file.file}`, { responseType: 'text' }));
      const parsed = await marked.parse(markdown || '');
      this.renderedHtml.set(typeof parsed === 'string' ? parsed : '');
    } catch {
      this.errorMessage.set('Impossibile caricare il file markdown selezionato.');
      this.renderedHtml.set('');
    } finally {
      this.loadingMarkdown.set(false);
    }
  }

  private async loadUpdatesIndex(): Promise<void> {
    this.loadingIndex.set(true);
    this.errorMessage.set('');

    try {
      const index = await firstValueFrom(this.http.get<UpdatesIndex>('/updates/index.json'));
      const files = index?.files ?? [];
      this.files.set(files);

      if (files.length > 0) {
        await this.selectUpdateFile(files[0]);
      } else {
        this.renderedHtml.set('');
      }
    } catch {
      this.errorMessage.set('Impossibile caricare la lista aggiornamenti.');
      this.files.set([]);
      this.renderedHtml.set('');
    } finally {
      this.loadingIndex.set(false);
    }
  }
}
