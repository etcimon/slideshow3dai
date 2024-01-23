import { libwasm, modules } from './modules'
import '../styles/index.css'
import { PGlite } from '@electric-sql/pglite';
(window as any).pglite = new PGlite('./db');
libwasm.libwasm.init(modules)