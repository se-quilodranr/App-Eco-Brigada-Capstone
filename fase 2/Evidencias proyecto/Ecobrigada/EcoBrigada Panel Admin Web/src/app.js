// EcoBrigada · Centro de administración.
// Sin service_role: la autorización real de cada lectura/escritura está en PostgreSQL.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2?bundle';
import {SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY} from './config.js';

const db=createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,{
 auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
});
const $=s=>document.querySelector(s);
const escapeHtml=x=>String(x??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
const E=escapeHtml;
const fmt=n=>{const raw=String(n??'0');return /^-?\d+(?:\.\d+)?$/.test(raw)?Number(raw).toLocaleString('es-CL'):raw};
const pct=(a,b)=>b?Math.round(Number(a)*100/Number(b)):0;
const date=d=>d?new Date(d).toLocaleDateString('es-CL',{day:'2-digit',month:'short',year:'numeric'}):'—';
const datetime=d=>d?new Date(d).toLocaleString('es-CL',{dateStyle:'short',timeStyle:'short'}):'—';
const initials=n=>String(n??'?').trim().split(/\s+/).slice(0,2).map(s=>s[0]?.toUpperCase()??'').join('');
const statusLabels={pendiente:'Pendiente',validado:'Validado',asignado:'Asignado',en_proceso:'En proceso',en_revision:'En revisión',cerrado:'Cerrado',descartado:'Descartado',abierta:'Abierta',cerrada:'Cerrada',programada:'Programada',en_curso:'En curso',finalizada:'Finalizada',aceptada:'Aceptada',rechazada:'Rechazada',admin:'Administrador',ciudadano:'Ciudadano'};
const label=x=>statusLabels[x]??String(x??'—').replaceAll('_',' ');
const statusColor=x=>['cerrado','finalizada','aceptada','abierta','validado','admin'].includes(x)?'green':['en_proceso','asignado','en_curso'].includes(x)?'blue':['pendiente','programada','en_revision'].includes(x)?'orange':['descartado','rechazada','cerrada'].includes(x)?'red':'';
const pill=(text,kind)=>`<span class="pill ${kind??statusColor(text)}">${E(label(text))}</span>`;
const btn=(text,action,id='',variant='')=>`<button class="act-btn ${variant}" data-action="${E(action)}" data-id="${E(id)}">${E(text)}</button>`;
const loading='<div class="loader">Cargando datos de Supabase…</div>';
let toastTimer;
function toast(text,error=false){const el=$('#toast');if(!el)return;clearTimeout(toastTimer);el.textContent=text;el.className='toast visible'+(error?' error':'');toastTimer=setTimeout(()=>el.className='toast',4500)}
const state={user:null,profile:null,view:'resumen',loading:false,error:'',data:{},filter:{},pages:{},modal:null,connected:false,refreshId:null,channel:null};
const views={
 resumen:{title:'Centro de control',desc:'Todo lo que sucede en tu comunidad, en un solo lugar.',icon:'◫',section:'PRINCIPAL'},
 usuarios:{title:'Gestión de usuarios',desc:'Consulta cuentas registradas, sus roles y participación.',icon:'♧',section:'GESTIÓN'},
 brigadas:{title:'Brigadas ambientales',desc:'Administra líderes, equipos, integrantes y disponibilidad.',icon:'♣',section:'GESTIÓN'},
 incidencias:{title:'Gestión de incidencias',desc:'Revisa, valida, asigna y da seguimiento a los casos ambientales.',icon:'◈',section:'GESTIÓN'},
 solicitudes:{title:'Solicitudes de ingreso',desc:'Aprueba o rechaza solicitudes de participación en brigadas.',icon:'✉',section:'GESTIÓN'},
 jornadas:{title:'Jornadas de limpieza',desc:'Calendario, participación y progreso de las actividades.',icon:'▣',section:'GESTIÓN'},
 estadisticas:{title:'Estadísticas completas',desc:'Indicadores reales calculados sobre toda la base de datos.',icon:'▥',section:'ANÁLISIS'},
 ecoanalisis:{title:'EcoAnálisis',desc:'Zonas críticas, alertas por plazos y posibles reincidencias.',icon:'◎',section:'ANÁLISIS'},
 auditoria:{title:'Auditoría de cambios',desc:'Trazabilidad de las decisiones tomadas desde el panel.',icon:'≡',section:'SISTEMA'}
};

async function rpc(name,args={}){
 const {data,error}=await db.rpc(name,args);if(error)throw error;return data;
}
async function init(){
 if(!SUPABASE_URL.startsWith('https://')||!SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')){
  $('#app').innerHTML='<div class="empty">Configura la URL y la clave pública en src/config.js.</div>';return;
 }
 const {data:{session}}=await db.auth.getSession();
 if(session){await checkAdmin(session.user)}else renderLogin();
 db.auth.onAuthStateChange((_event,session)=>{
  // Programar fuera del callback para no bloquear las operaciones de Auth.
  setTimeout(()=>{if(!session){clearRealtime();state.user=null;state.profile=null;renderLogin()}else if(state.user?.id!==session.user.id)checkAdmin(session.user)},0);
 });
 window.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'&&state.user)loadData(false)});
 setInterval(()=>{if(state.user&&document.visibilityState==='visible')loadData(false)},60000);
}
async function checkAdmin(user){
 try{
  const {data,error}=await db.from('perfiles').select('id,nombre,role').eq('id',user.id).single();
  if(error)throw error;
  state.user=user;state.profile=data;
  if(data.role!=='admin'){renderDenied();return;}
  listenRealtime();render();await loadData();
 }catch(err){state.user=null;renderLogin('No fue posible verificar tu rol: '+err.message)}
}
function renderDenied(){clearRealtime();$('#app').innerHTML=`<div class="auth-wrap"><div class="auth-hero"><div class="auth-brand">❧ EcoBrigada</div><div><h1>Acceso protegido.</h1><p>El panel es exclusivo para administradores autorizados.</p></div><div class="auth-caption">La autorización se comprueba en Supabase.</div></div><div class="auth-right"><div class="auth-box"><span class="eyebrow">PERMISOS</span><h2>Sin acceso de administrador</h2><p>Tu cuenta ${E(state.user?.email)} tiene el rol ${E(state.profile?.role)}. Solicita permisos a un administrador actual.</p><button class="btn primary" data-action="logout">Cerrar sesión</button></div></div></div>`}
function renderLogin(message=''){$('#app').innerHTML=`<div class="auth-wrap"><section class="auth-hero"><div class="auth-brand">◈ EcoBrigada <span style="font-size:10px;opacity:.75;letter-spacing:.12em;margin-left:4px">ADMIN</span></div><div><p class="eyebrow" style="color:#a4e4b6">UN MISMO ECOSISTEMA</p><h1>Gestiona el cambio. Mide el impacto.</h1><p>Un espacio exclusivo para coordinar personas, brigadas y acciones que transforman tu comunidad.</p></div><div class="auth-caption">© EcoBrigada · Administración ambiental inteligente</div></section><section class="auth-right"><div class="auth-box"><span class="eyebrow">ACCESO ADMINISTRATIVO</span><h2>Bienvenido de nuevo</h2><p>Inicia sesión con tu cuenta administradora de EcoBrigada.</p><form id="login-form"><label for="email">Correo electrónico</label><input id="email" name="email" type="email" autocomplete="username" required placeholder="correo@ejemplo.com"/><label for="password">Contraseña</label><input id="password" name="password" type="password" autocomplete="current-password" required placeholder="••••••••"/><button type="submit" class="btn primary">Ingresar al panel →</button><div class="auth-error" id="login-error">${E(message)}</div></form><p class="small" style="margin-top:28px">El inicio de sesión usa las mismas credenciales y Supabase Auth de la aplicación móvil.</p></div></section></div>`}
async function login(form){const email=form.elements.email.value.trim();const password=form.elements.password.value;const submit=form.querySelector('button');submit.disabled=true;try{const {data,error}=await db.auth.signInWithPassword({email,password});if(error)throw error;await checkAdmin(data.user)}catch(err){const el=$('#login-error');if(el)el.textContent=(err.message?.includes('Invalid login')?'Correo o contraseña incorrectos':err.message)}finally{submit.disabled=false}}
function clearRealtime(){if(state.channel)db.removeChannel(state.channel);state.channel=null;state.connected=false;if(state.refreshId)clearTimeout(state.refreshId)}
function listenRealtime(){clearRealtime();const channel=db.channel('eco-admin-cambios');for(const table of ['perfiles','brigadas','brigada_miembros','incidencias','actividades','solicitudes','historial_incidencias']){
 channel.on('postgres_changes',{event:'*',schema:'public',table},()=>{
  clearTimeout(state.refreshId);state.refreshId=setTimeout(()=>{if(state.user)loadData(false)},950);
 });
 }
 state.channel=channel;channel.subscribe(status=>{state.connected=status==='SUBSCRIBED';const badge=$('#live-badge');if(badge){badge.className='live'+(state.connected?'':' offline');badge.textContent=state.connected?'Sincronización activa':'Sincronizando';}});
}
function render(){const nav=Object.entries(views).map(([key,v],i,all)=>`${i===0||v.section!==all[i-1][1].section?`<div class="nav-title">${E(v.section)}</div>`:''}<button class="nav-btn ${state.view===key?'active':''}" data-view="${key}"><span class="nav-icon">${v.icon}</span>${E(v.title)}</button>`).join('');
 $('#app').innerHTML=`<div class="layout"><aside class="sidebar" id="sidebar"><div class="brand"><div class="brand-badge">❧</div><div><div class="brand-title">EcoBrigada</div><div class="brand-sub">ADMINISTRATION</div></div></div>${nav}<div class="sidebar-foot"><div class="side-help"><h4>◉ Datos compartidos</h4><p>El panel y la aplicación utilizan el mismo Supabase. Las acciones se aplican directamente a sus tablas.</p></div><div class="signed"><div class="signed-av">${E(initials(state.profile?.nombre))}</div><div><div class="signed-name">${E(state.profile?.nombre)}</div><div class="signed-role">Administrador global</div></div></div><button class="nav-btn" data-action="logout" style="margin-top:10px"><span class="nav-icon">↪</span>Cerrar sesión</button></div></aside><div class="workspace"><header class="topbar"><div class="top-left"><button class="top-icon mobile-nav-toggle" data-action="menu" aria-label="Abrir menú">☰</button><span class="bread">EcoBrigada <span style="margin:0 7px;color:#c5d1c9">/</span> <strong>${E(views[state.view].title)}</strong></span></div><div class="top-actions"><span class="today">${E(new Date().toLocaleDateString('es-CL',{weekday:'long',day:'numeric',month:'long'}))}</span><span class="live ${state.connected?'':'offline'}" id="live-badge">${state.connected?'Sincronización activa':'Sincronizando'}</span><button class="top-icon" data-action="refresh" title="Actualizar">↻</button></div></header><main class="content" id="main">${loading}</main></div></div>`;
}
function pageHead(extra=''){const p=views[state.view];return `<div class="page-head"><div><p class="eyebrow">ECOBRIGADA / ${E(p.section)}</p><h1>${E(p.title)}</h1><p class="page-desc">${E(p.desc)}</p></div>${extra}</div>`}
function stat(icon,value,labelText,note,cls=''){return `<div class="stat-card"><div class="stat-top"><span class="stat-ic ${cls}">${icon}</span></div><div class="stat-value mono">${E(value)}</div><div class="stat-label">${E(labelText)}</div><div class="stat-note">${E(note)}</div></div>`}
function boxTitle(title,desc='',right=''){return `<div class="section-heading"><div><h3>${E(title)}</h3>${desc?`<p>${E(desc)}</p>`:''}</div>${right}</div>`}
function hbars(rows,max=0){if(!rows?.length)return '<div class="empty">Sin información en este período.</div>';const m=max||Math.max(1,...rows.map(r=>Number(r.cantidad||0)));return `<div class="horizontal-bars">${rows.map(r=>`<div class="hbar-item"><div class="hbar-top"><span>${E(label(r.nombre))}</span><strong>${fmt(r.cantidad)}</strong></div><div class="hbar-line"><span style="width:${Math.max(2,Math.round(Number(r.cantidad)*100/m))}%"></span></div></div>`).join('')}</div>`}
function weeklyChart(rows){if(!rows?.length)return '<div class="empty">Todavía no hay registros semanales.</div>';const m=Math.max(1,...rows.flatMap(r=>[Number(r.reportes),Number(r.resueltas)]));return `<div class="bar-chart">${rows.map(r=>`<div class="bar-col"><div class="bar-pair"><div class="bar" title="${E(r.reportes)} reportes" style="height:${Math.max(1,Number(r.reportes)/m*98)}%"></div><div class="bar amber" title="${E(r.resueltas)} resueltas" style="height:${Math.max(1,Number(r.resueltas)/m*98)}%"></div></div><span class="axis-label">${E(r.semana)}</span></div>`).join('')}</div><div class="chart-legend"><span><i class="legend-dot"></i>Incidencias registradas</span><span><i class="legend-dot amber"></i>Incidencias cerradas</span></div>`}
const chartColors=['#238967','#f0ad65','#7a9cbd','#9c83ba','#d85e61','#73bb91','#c19f65'];
function donut(rows){const total=rows.reduce((a,r)=>a+Number(r.cantidad),0);if(!total)return '<div class="empty">No hay incidencias.</div>';let from=0;const gradients=rows.map((r,i)=>{const pctVal=Number(r.cantidad)/total*100;const p=`${chartColors[i%chartColors.length]} ${from.toFixed(2)}% ${(from+pctVal).toFixed(2)}%`;from+=pctVal;return p}).join(',');return `<div class="donut-row"><div class="donut" style="background:conic-gradient(${gradients})"><div class="donut-hole"><strong>${fmt(total)}</strong><span>incidencias</span></div></div><div class="legend-list">${rows.map((r,i)=>`<div class="legend-line"><i class="legend-swatch" style="background:${chartColors[i%chartColors.length]}"></i>${E(label(r.nombre))}<span>${fmt(r.cantidad)}</span></div>`).join('')}</div></div>`}
function rankList(rows){if(!rows?.length)return '<div class="empty">Aún no existen brigadas registradas.</div>';const m=Math.max(1,...rows.map(x=>Number(x.asignadas)));return `<div class="rank-list">${rows.slice(0,8).map((r,i)=>`<div class="rank-item"><span class="rank-number">${String(i+1).padStart(2,'0')}</span><div><div class="rank-name">${E(r.nombre)}</div><div class="rank-sub">${E(r.comuna)} · ${fmt(r.miembros)} integrantes · ${fmt(r.asignadas)} asignadas</div><div class="progress-track"><div class="progress-fill" style="width:${Math.round(Number(r.asignadas)*100/m)}%"></div></div></div><div class="rank-score" title="Incidencias cerradas">${fmt(r.cerradas)}<span class="small muted"> ✓</span></div></div>`).join('')}</div>`}
function analyticsCards(s){return `<div class="stat-grid">${stat('♧',fmt(s.usuarios),'Usuarios registrados',`${fmt(s.administradores)} administradores y ${fmt(s.lideres)} líderes de brigada`)}${stat('◈',fmt(s.incidencias),'Incidencias registradas',`${fmt(s.activas)} activas · ${fmt(s.cerradas)} cerradas`,'orange')}${stat('✓',pct(s.cerradas,s.incidencias)+'%','Tasa de resolución','Porcentaje de incidencias cerradas sobre el total')}${stat('▣',fmt(s.jornadas),'Jornadas organizadas',`${fmt(s.jornadas_finalizadas)} finalizadas`,'purple')}</div>`}
function renderOverview(s,a){return `${pageHead(`<button class="btn" data-action="refresh">↻ Actualizar datos</button>`)}${analyticsCards(s)}<div class="dash-grid"><section class="panel">${boxTitle('Actividad de la comunidad','Incidencias nuevas y cerradas · últimas 12 semanas',`<span class="pill green">Actualizado</span>`)}${weeklyChart(s.semanas)}</section><section class="panel">${boxTitle('Estado de incidencias','Distribución por etapa del proceso')}${donut(s.estados)}</section></div><div class="split"><section class="panel">${boxTitle('Brigadas con mayor actividad','Casos asignados y cerrados por equipo',`<button class="btn tiny" data-view="brigadas">Ver brigadas</button>`)}${rankList(s.brigadas_ranking)}</section><section class="panel">${boxTitle('Prioridades actuales','Clasificación según el puntaje de gravedad')}${hbars(s.prioridades)}<div style="padding:0 21px 22px"><button class="btn tiny" data-view="ecoanalisis">Explorar EcoAnálisis →</button></div></section></div><div class="metric-strip">${mini('⚑',s.alertas_vencidas,'Plazos orientativos vencidos')}${mini('⌁',s.solicitudes_pendientes,'Solicitudes de ingreso pendientes')}${mini('◎',s.en_revision,'Incidencias a la espera de revisión')}${mini('♧',s.brigadas,'Brigadas registradas')}${mini('◷',s.promedio_dias+' d','Tiempo medio de resolución')}</div><div class="panel">${boxTitle('Atención prioritaria','Incidencias que superan los plazos operativos orientativos',`<button class="btn tiny" data-view="ecoanalisis">Ver todas las alertas</button>`)}${alertsTable(a.items??[],true)}</div>`}
function mini(icon,value,title){return `<div class="mini-metric"><span style="font-size:16px;color:var(--green)">${icon}</span> <strong>${E(fmt(value))}</strong><p>${E(title)}</p></div>`}
function paginate(result){const total=Number(result?.total??0),offset=state.pages[state.view]??0,limit=30;return `<div class="pagination"><span>${total?`${fmt(offset+1)}–${fmt(Math.min(total,offset+limit))}`:'0'} de ${fmt(total)} registros</span><div class="toolbar"><button class="btn tiny" data-action="prev" ${offset<=0?'disabled':''}>← Anterior</button><button class="btn tiny" data-action="next" ${offset+limit>=total?'disabled':''}>Siguiente →</button></div></div>`}
function filterBar({status=false,placeholder='Buscar por nombre, comuna o dirección'}){const f=state.filter[state.view]??{};return `<form class="toolbar" id="filter-form"><input class="field search" name="buscar" aria-label="Buscar" placeholder="${E(placeholder)}" value="${E(f.buscar??'')}">${status?`<select class="select" name="estado" aria-label="Filtrar por estado"><option value="">Todos los estados</option>${['pendiente','validado','asignado','en_proceso','en_revision','cerrado','descartado'].map(x=>`<option value="${x}" ${f.estado===x?'selected':''}>${E(label(x))}</option>`).join('')}</select>`:''}<button class="btn primary" type="submit">⌕ Buscar</button><button type="button" class="btn" data-action="reset">Limpiar</button></form>`}
function table(head,rows,emptyText='No hay registros para los filtros actuales.'){return `<div class="table-scroll"><table class="data-table"><thead><tr>${head.map(x=>`<th>${E(x)}</th>`).join('')}</tr></thead><tbody>${rows?.length?rows.join(''):`<tr><td colspan="${head.length}"><div class="empty">${E(emptyText)}</div></td></tr>`}</tbody></table></div>`}
function usersPage(r){const rows=r.items.map(u=>`<tr><td><div class="person"><div class="initials">${E(initials(u.nombre))}</div><div><div class="table-title">${E(u.nombre)}</div><div class="subtext">${E(u.email)}</div></div></div></td><td>${pill(u.role,u.role==='admin'?'green':'')}</td><td>${fmt(u.lidera)}</td><td>${fmt(u.pertenece)}</td><td>${fmt(u.reportes)}</td><td>${date(u.creado_en)}</td><td><div class="table-actions">${btn('Cambiar rol','role',u.id)}${u.id===state.user?.id?'<span class="pill">Tu cuenta</span>':Number(u.lidera)>0?'<span class="pill orange" title="Primero debes reasignar las brigadas que lidera">Reasigna líder antes de eliminar</span>':btn('Eliminar','delete-user',u.id,'red')}</div></td></tr>`);return `${pageHead(filterBar({placeholder:'Buscar nombre o correo electrónico'}))}<div class="note-box">Los permisos globales son <strong>Ciudadano</strong> o <strong>Administrador</strong>. El permiso <strong>Jefe de brigada</strong> se asigna desde la sección Brigadas; no es un rol global. No se muestran contraseñas, RUT ni direcciones privadas. La eliminación desactiva la cuenta de Auth de manera irreversible y anonimiza su perfil; conserva los reportes históricos. Antes de eliminar un jefe, debes reasignar sus brigadas.</div><section class="panel">${boxTitle('Directorio de usuarios',`${fmt(r.total)} cuentas registradas`)}${table(['USUARIO','ROL GLOBAL','LIDERA','PERTENECE','REPORTES','REGISTRO','PERMISOS'],rows)}${paginate(r)}</section>`}
function brigadesPage(r){const rows=r.items.map(b=>`<tr><td><div class="table-title">${E(b.nombre)}</div><div class="subtext">${E(b.comuna)}</div></td><td>${E(b.lider??'Sin líder')}</td><td>${fmt(b.miembros)}</td><td>${fmt(b.incidencias)}</td><td>${fmt(b.resueltas)}</td><td>${pill(b.estado)}</td><td><div class="table-actions">${btn('Líder','leader',b.id)}${btn('Integrantes','members',b.id)}${btn(b.estado==='abierta'?'Cerrar':'Abrir','brigade-state',b.id)}</div></td></tr>`);return `${pageHead(filterBar({placeholder:'Buscar brigada o comuna'}))}<section class="panel">${boxTitle('Directorio de brigadas',`${fmt(r.total)} equipos ambientales`)}${table(['BRIGADA','JEFE / LÍDER','MIEMBROS','CASOS','CERRADOS','ESTADO','GESTIÓN'],rows)}${paginate(r)}</section>`}
function incidentsPage(r){const rows=r.items.map(i=>`<tr><td><div class="table-title">${E(i.titulo)}</div><div class="subtext">${E(i.tipo)} · ${E(i.comuna)} · ${date(i.creado_en)}</div></td><td>${pill(i.estado)}</td><td>${priorityPill(i.prioridad)}</td><td>${E(i.brigada??'Sin asignar')}</td><td>${E(i.autor??'—')}</td><td>${i.tiene_informe?pill('Informe recibido','green'):'—'}</td><td>${btn('Gestionar','incident',i.id)}</td></tr>`);return `${pageHead(filterBar({status:true,placeholder:'Buscar título, comuna o dirección'}))}<div class="note-box">Los cambios de estado utilizan las mismas transiciones del backend móvil. Para cerrar una incidencia, se requiere el informe final del jefe y evidencia fotográfica posterior.</div><section class="panel">${boxTitle('Seguimiento de reportes',`${fmt(r.total)} resultados`)}${table(['INCIDENCIA','ESTADO','PRIORIDAD','BRIGADA ASIGNADA','REPORTÓ','INFORME','ACCIÓN'],rows)}${paginate(r)}</section>`}
function priorityPill(n){const v=Number(n);return `<span class="pill ${v>=70?'red':v>=40?'orange':'green'}">${v}/100 · ${v>=70?'Alta':v>=40?'Media':'Baja'}</span>`}
function activitiesPage(r){const rows=r.items.map(a=>`<tr><td><div class="table-title">${E(a.titulo)}</div><div class="subtext">${E(a.brigada??'—')}</div></td><td>${date(a.fecha_inicio)}</td><td>${fmt(a.participantes)} personas</td><td>${pill(a.estado)}</td><td>${['programada','en_curso'].includes(a.estado)?btn('Avanzar estado','activity',a.id):'—'}</td></tr>`);return `${pageHead()}<section class="panel">${boxTitle('Jornadas registradas',`${fmt(r.total)} actividades`)}${table(['ACTIVIDAD','FECHA','INSCRITOS','ESTADO','GESTIÓN'],rows)}${paginate(r)}</section>`}
function requestsPage(r){const f=state.filter.solicitudes??{};const rows=r.items.map(s=>`<tr><td><div class="table-title">${E(s.usuario)}</div><div class="subtext">${E(s.email??'')}</div></td><td>${E(s.brigada)}</td><td><div style="max-width:235px;white-space:normal">${E(s.mensaje||'Sin mensaje')}</div></td><td>${date(s.enviada_en)}</td><td>${pill(s.estado)}</td><td>${s.estado==='pendiente'?`<div class="table-actions">${btn('Aceptar','request-yes',s.id)}${btn('Rechazar','request-no',s.id)}</div>`:'—'}</td></tr>`);return `${pageHead(`<div class="toolbar"><select class="select" id="request-filter"><option value="pendiente" ${f.estado!=='aceptada'&&f.estado!=='rechazada'&&f.estado!==''?'selected':''}>Pendientes</option><option value="" ${f.estado===''?'selected':''}>Todas</option><option value="aceptada" ${f.estado==='aceptada'?'selected':''}>Aceptadas</option><option value="rechazada" ${f.estado==='rechazada'?'selected':''}>Rechazadas</option></select></div>`)}<section class="panel">${boxTitle('Solicitudes de las brigadas',`${fmt(r.total)} solicitudes`)}${table(['PERSONA','BRIGADA','MENSAJE','RECIBIDA','ESTADO','RESPUESTA'],rows)}${paginate(r)}</section>`}
function statsPage(s){return `${pageHead(`<button class="btn primary" data-action="export-stats">↓ Descargar CSV de indicadores</button>`)}<div class="note-box">Los indicadores de esta página se calculan en PostgreSQL sobre <strong>todos los registros</strong> de Supabase. Se actualizan cuando la app o el panel modifican la información.</div>${analyticsCards(s)}<div class="stat-grid">${stat('♣',fmt(s.brigadas),'Brigadas registradas',`${fmt(s.brigadas_abiertas)} abiertas · ${fmt(s.integrantes)} vínculos de miembros`)}${stat('◷',s.promedio_dias+' días','Tiempo medio de resolución','Desde el registro hasta el cierre de cada caso','purple')}${stat('⊞',fmt(s.informes_finales),'Informes finales recibidos',`${fmt(s.kilos_estimados)} kg estimados recuperados`)}${stat('⚑',fmt(s.alertas_vencidas),'Alertas por plazo','Incidencias abiertas que exceden el plazo orientativo','red')}</div><div class="dash-grid"><section class="panel">${boxTitle('Evolución de reportes','12 semanas · registros y cierres')}${weeklyChart(s.semanas)}</section><section class="panel">${boxTitle('Distribución por estados','Todas las incidencias')}${donut(s.estados)}</section></div><div class="split"><section class="panel">${boxTitle('Tipos de residuos','Clasificación de los reportes')}${hbars(s.tipos)}</section><section class="panel">${boxTitle('Nivel de prioridad','Alta ≥70, media ≥40, baja <40')}${hbars(s.prioridades)}</section></div><div class="split"><section class="panel">${boxTitle('Comunas con más reportes','Incluye casos activos y cerrados')}${hbars(s.comunas)}</section><section class="panel">${boxTitle('Estado de las jornadas','Progreso de actividades programadas')}${hbars(s.jornadas_estado)}<div class="metric-strip" style="padding:0 20px 20px;margin:0">${mini('⌁',s.solicitudes_pendientes,'Solicitudes pendientes')}${mini('◎',s.en_revision,'Incidencias en revisión')}</div></section></div><section class="panel">${boxTitle('Desempeño de brigadas','Ranking por cierres y asignaciones')}${rankList(s.brigadas_ranking)}</section>`}
function alertsTable(items,short=false){return table(['ALERTA','PRIORIDAD','ESTADO','ANTIGÜEDAD','PLAZO'],items.map(a=>`<tr><td><div class="table-title">${E(a.titulo)}</div><div class="subtext">${E(a.comuna)}</div></td><td>${priorityPill(a.prioridad)}</td><td>${pill(a.estado)}</td><td>${E(a.antiguedad_dias)} días</td><td>${E(a.plazo_dias)} días</td></tr>`),short?'No hay alertas vencidas.':'No se encontraron alertas.');}
function recidTable(items){return table(['NUEVA INCIDENCIA','ANTECEDENTE CERRADO','DISTANCIA','TIEMPO TRANSCURRIDO','ESTADO'],items.map(r=>`<tr><td><div class="table-title">${E(r.titulo)}</div><div class="subtext">${E(r.comuna)} · ${E(r.tipo)}</div></td><td><div class="table-title">${E(r.titulo_anterior)}</div></td><td>${E(r.distancia_m)} m</td><td>${E(r.dias)} días</td><td>${pill(r.estado)}</td></tr>`),'Sin reincidencias detectadas mediante los criterios del análisis.');}
function ecoPage(s,zonas,alertas,recid){const sub=state.filter.ecoanalisis?.sub??'zonas';const titles={zonas:'EcoZonas',alertas:'EcoAlerta',reincidencias:'EcoReincidencia'};const inner=sub==='zonas'?`<div class="note-box">Agrupación territorial <strong>aproximada</strong> en celdas de ~200–250 m, con un mínimo de 3 incidencias activas. No sustituye una medición geoespacial exacta.</div><div class="split"><section class="panel">${boxTitle('Focos de incidencias','Agrupaciones de reportes activos')}${zonas.length?zonas.map((z,i)=>`<div class="geo-card"><div><strong>${i+1}. ${E(z.comuna)}</strong><div class="subtext">Centro: ${z.lat}, ${z.lng} · ${fmt(z.casos)} incidencias activas</div><div class="subtext">Prioridad media: ${z.prioridad_media}/100 · ${fmt(z.alta_prioridad)} de prioridad alta</div></div><span class="pill orange">${fmt(z.casos)} casos</span></div>`).join(''):'<div class="empty">Aún no se identifican agrupaciones.</div>'}</section><section class="panel">${boxTitle('Concentración por comuna','Total de incidencias registradas')}${hbars(s.comunas)}</section></div>`:sub==='alertas'?`<div class="note-box warn-box">Los plazos de EcoAlerta son <strong>orientativos</strong>: prioridad alta 2 días, media 5 días y baja 10 días. No son obligaciones legales ni compromisos de atención.</div><section class="panel">${boxTitle('Todas las alertas vencidas',`${fmt(alertas.total)} coincidencias · resultados paginados`)}${alertsTable(alertas.items??[])}${paginate(alertas)}</section>`:`<div class="note-box">Posibles reincidencias: nuevos reportes <strong>del mismo tipo</strong> a 250 metros o menos de un caso cerrado previamente. Una coincidencia no demuestra que los residuos provengan de la misma causa.</div><section class="panel">${boxTitle('Todas las posibles reincidencias',`${fmt(recid.total)} coincidencias · resultados paginados`)}${recidTable(recid.items??[])}${paginate(recid)}</section>`;
return `${pageHead()}<div class="stat-grid">${stat('◎',fmt(zonas.length),'Zonas agrupadas','Agrupaciones de tres o más casos activos')}${stat('⚑',fmt(s.alertas_vencidas),'Plazos vencidos','Incidencias que superan el plazo orientativo','red')}${stat('↺',fmt(recid.total),'Posibles reincidencias','Nuevos reportes cercanos a limpiezas anteriores','orange')}${stat('⧖',s.promedio_dias+' d','Resolución media','Duración de los casos cerrados')}</div><div class="tabs" style="width:max-content;max-width:100%;margin-bottom:17px">${Object.entries(titles).map(([key,val])=>`<button class="tab ${sub===key?'active':''}" data-action="eco-tab" data-id="${key}">${val}</button>`).join('')}</div>${inner}`}
function auditPage(r){const rows=r.items.map(a=>`<tr><td>${datetime(a.creado_en)}</td><td><strong>${E(a.actor)}</strong></td><td>${pill(a.accion.replaceAll('_',' '),'blue')}</td><td>${E(a.entidad)}</td><td><span class="small" style="white-space:normal;display:block;max-width:400px">${E(JSON.stringify(a.detalle??{}))}</span></td></tr>`);return `${pageHead()}<div class="note-box">Registro de los cambios administrativos realizados desde este panel. Los cambios anteriores y los movimientos de incidencia realizados desde la app se conservan en sus historiales originales.</div><section class="panel">${boxTitle('Historial de decisiones',`${fmt(r.total)} acciones registradas`)}${table(['FECHA','ADMINISTRADOR','ACCIÓN','ENTIDAD','DETALLE'],rows)}${paginate(r)}</section>`}

const getFilter=()=>state.filter[state.view]??{};
const getOffset=()=>state.pages[state.view]??0;
async function loadData(showLoader=true){
 if(!state.user||state.profile?.role!=='admin')return;
 if(state.loading)return;
 state.loading=true;state.error='';
 const host=$('#main');if(host&&showLoader)host.innerHTML=pageHead()+loading;
 try{
  const f=getFilter(),p=getOffset();let data={};
  if(state.view==='resumen'){
   const [stats,alerts]=await Promise.all([rpc('eco_admin_estadisticas'),rpc('eco_admin_alertas',{p_limite:5,p_desde:0})]);
   data={stats,alerts};
  }else if(state.view==='usuarios')data={rows:await rpc('eco_admin_usuarios',{p_buscar:f.buscar??'',p_limite:30,p_desde:p})};
  else if(state.view==='brigadas')data={rows:await rpc('eco_admin_brigadas',{p_buscar:f.buscar??'',p_limite:30,p_desde:p})};
  else if(state.view==='incidencias'){const [rows,brigades]=await Promise.all([rpc('eco_admin_incidencias',{p_buscar:f.buscar??'',p_estado:f.estado??'',p_limite:30,p_desde:p}),rpc('eco_admin_brigadas',{p_limite:100,p_desde:0})]);data={rows,brigades:brigades.items??[]};}
  else if(state.view==='jornadas')data={rows:await rpc('eco_admin_jornadas',{p_limite:30,p_desde:p})};
  else if(state.view==='solicitudes')data={rows:await rpc('eco_admin_solicitudes',{p_estado:f.estado===undefined?'pendiente':f.estado,p_limite:30,p_desde:p})};
  else if(state.view==='estadisticas')data={stats:await rpc('eco_admin_estadisticas')};
  else if(state.view==='ecoanalisis'){
   const sub=f.sub??'zonas';const calls=[rpc('eco_admin_estadisticas'),rpc('eco_admin_zonas'),rpc('eco_admin_alertas',{p_limite:30,p_desde:sub==='alertas'?p:0}),rpc('eco_admin_reincidencias',{p_limite:30,p_desde:sub==='reincidencias'?p:0})];
   const [stats,zonas,alertas,recid]=await Promise.all(calls);data={stats,zonas,alertas,recid};
  }else if(state.view==='auditoria')data={rows:await rpc('eco_admin_auditoria_listar',{p_limite:30,p_desde:p})};
  state.data[state.view]=data;
  updateContent();
 }catch(err){
  state.error=err.message||String(err);
  const host=$('#main');if(host)host.innerHTML=pageHead()+`<div class="panel panel-pad"><h2>No se pudieron cargar los datos</h2><p class="muted">${E(state.error)}</p><p class="small muted">Comprueba que ejecutaste el SQL <code>supabase/20261118_panel_admin.sql</code> en el mismo proyecto y que tu cuenta tenga el rol administrador.</p><button class="btn primary" data-action="refresh">Reintentar</button></div>`;
  console.error(err);
 }finally{state.loading=false;}
}
function updateContent(){const d=state.data[state.view],host=$('#main');if(!host||!d)return;
 const renderer={
  resumen:()=>renderOverview(d.stats,d.alerts),usuarios:()=>usersPage(d.rows),brigadas:()=>brigadesPage(d.rows),
  incidencias:()=>incidentsPage(d.rows),solicitudes:()=>requestsPage(d.rows),jornadas:()=>activitiesPage(d.rows),
  estadisticas:()=>statsPage(d.stats),ecoanalisis:()=>ecoPage(d.stats,d.zonas,d.alertas,d.recid),auditoria:()=>auditPage(d.rows)
 }[state.view];host.innerHTML=renderer?renderer():loading;
}
async function navigate(next){if(!views[next]||!state.user)return;state.view=next;state.pages[next]=0;render();await loadData();window.scrollTo({top:0,behavior:'instant'});}
function dismissModal(){const el=$('#modal-root');if(el)el.remove();state.modal=null;}
function showModal(title,html,options={}){
 dismissModal();state.modal=options;
 const wrap=document.createElement('div');wrap.id='modal-root';wrap.className='overlay';wrap.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="${E(title)}"><div class="modal-head"><h2>${E(title)}</h2><button class="modal-close" data-action="close-modal" title="Cerrar">×</button></div>${html}</div>`;
 document.body.appendChild(wrap);
}
function usersSelect(items,selected='',name='usuario'){return `<select class="select" name="${E(name)}" required><option value="">Selecciona una persona</option>${items.map(u=>`<option value="${E(u.id)}" ${selected===u.id?'selected':''}>${E(u.nombre)} (${E(u.email??u.role??'')})</option>`).join('')}</select>`}
async function getChoices(){const [users,brigades]=await Promise.all([rpc('eco_admin_usuarios',{p_limite:100,p_desde:0}),rpc('eco_admin_brigadas',{p_limite:100,p_desde:0})]);return {users:users.items??[],brigades:brigades.items??[],totalUsers:users.total,totalBrigades:brigades.total}}
async function openRole(id){const u=state.data.usuarios?.rows?.items?.find(x=>x.id===id);if(!u)return;
 showModal('Modificar permisos globales',`<div class="note-box"><strong>${E(u.nombre)}</strong><br>${E(u.email)}<br>El rol "jefe" se asigna por brigada, no como permiso global.</div><form id="change-role-form" data-id="${E(id)}"><div class="form-grid"><div><label class="form-label">Rol global</label><select class="select" name="rol"><option value="ciudadano" ${u.role==='ciudadano'?'selected':''}>Ciudadano</option><option value="admin" ${u.role==='admin'?'selected':''}>Administrador global</option></select></div></div><div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cancelar</button><button class="btn primary" type="submit">Guardar permisos</button></div></form>`,{type:'role'});
}
async function openDeleteUser(id){
 const u=state.data.usuarios?.rows?.items?.find(x=>x.id===id);
 if(!u)return;
 if(id===state.user?.id){toast('No puedes eliminar tu propia cuenta administrativa',true);return;}
 if(Number(u.lidera)>0){toast('Debes reasignar las brigadas que lidera antes de eliminarlo',true);return;}
 showModal('Eliminar cuenta de usuario',`<div class="note-box warn-box"><strong>Acción irreversible</strong><br>La cuenta de acceso de <strong>${E(u.nombre)}</strong> (${E(u.email)}) se eliminará de Supabase Auth. El perfil será anonimizado, pero los reportes y la actividad histórica se conservan para las estadísticas. No borra automáticamente imágenes almacenadas ni el contenido de mensajes.</div><form id="delete-user-form" data-id="${E(id)}"><label class="form-label">Confirma escribiendo el correo completo</label><input class="field full" name="correo" type="email" required autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="${E(u.email)}"><label class="form-label" style="margin-top:12px">Escribe ELIMINAR</label><input class="field full" name="confirmacion" required autocomplete="off" spellcheck="false" placeholder="ELIMINAR"><div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cancelar</button><button class="btn danger" type="submit">Eliminar cuenta</button></div></form>`,{type:'delete-user'});
}
async function deleteUserFromPanel(form){
 const id=form.dataset.id;
 const u=state.data.usuarios?.rows?.items?.find(x=>x.id===id);
 if(!u){toast('Actualiza el listado e inténtalo de nuevo',true);return;}
 const correo=form.elements.correo.value.trim();
 if(correo.toLowerCase()!==String(u.email).toLowerCase()||form.elements.confirmacion.value.trim()!=='ELIMINAR'){
  toast('Debes introducir el correo exacto y la palabra ELIMINAR',true);return;
 }
 const submit=form.querySelector('button[type="submit"]');submit.disabled=true;
 try{
  const {data,error}=await db.functions.invoke('eco-admin-eliminar-usuario',{body:{usuario_id:id,correo_confirmacion:correo,confirmacion:'ELIMINAR'}});
  if(error){let m=error.message??'Error al eliminar usuario';if(error.context?.json){try{const detail=await error.context.json();m=detail.error??detail.message??m;}catch{}}throw Error(m)}
  if(!data?.ok)throw Error(data?.error??'No se confirmó la eliminación');
  dismissModal();toast(data.advertencias?.length?`Cuenta eliminada; revisa las advertencias: ${data.advertencias.join(' | ')}`:'Cuenta eliminada y perfil anonimizado');
  state.pages.usuarios=0;await loadData();
 }catch(e){toast(e.message??String(e),true)}finally{submit.disabled=false}
}
async function openLeader(id){const b=state.data.brigadas?.rows?.items?.find(x=>x.id===id);if(!b)return;try{const c=await getChoices();showModal('Asignar jefe de brigada',`<div class="note-box"><strong>${E(b.nombre)}</strong> · ${E(b.comuna)}<br>Líder actual: ${E(b.lider??'Ninguno')}. Al cambiarlo, el anterior conservará su pertenencia como integrante.</div><form id="change-leader-form" data-id="${E(id)}"><label class="form-label">Nuevo jefe</label>${usersSelect(c.users,b.lider_uid)}${c.totalUsers>100?'<p class="query-hint">La lista muestra las primeras 100 cuentas. Puedes buscar más desde el directorio de usuarios.</p>':''}<div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cancelar</button><button class="btn primary">Asignar líder</button></div></form>`,{type:'leader'});}catch(e){toast(e.message,true)}}
async function openMembers(id){const b=state.data.brigadas?.rows?.items?.find(x=>x.id===id);if(!b)return;try{const [members,choices]=await Promise.all([rpc('eco_admin_miembros',{p_brigada:id}),getChoices()]);showModal('Integrantes de la brigada',`<div class="note-box"><strong>${E(b.nombre)}</strong> · ${fmt(members.length)} integrantes visibles<br>El líder no puede retirarse mientras siga asignado.</div><div style="max-height:265px;overflow:auto;margin-bottom:19px">${members.length?members.map(m=>`<div class="geo-card"><div><strong>${E(m.nombre)}</strong><div class="subtext">${E(m.email)} · ${E(label(m.rol))}</div></div>${m.id!==b.lider_uid?`<button class="act-btn" data-action="remove-member" data-id="${E(m.id)}" data-brigade="${E(id)}">Quitar</button>`:pill('Jefe','green')}</div>`).join(''):'<div class="empty">Sin miembros</div>'}</div><form id="add-member-form" data-id="${E(id)}"><label class="form-label">Incorporar un usuario existente</label>${usersSelect(choices.users)}<div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cerrar</button><button class="btn primary" type="submit">Agregar integrante</button></div></form>`,{type:'members'});}catch(e){toast(e.message,true)}}
function openIncident(id){const item=state.data.incidencias?.rows?.items?.find(x=>x.id===id);if(!item)return;
 const opts={pendiente:['validado','descartado'],validado:['asignado','descartado'],asignado:['en_proceso'],en_revision:['cerrado','en_proceso']}[item.estado]??[];
 const brigades=state.data.incidencias?.brigades??[];
 const selectOpts=opts.map(o=>`<option value="${E(o)}">${E(label(o))}</option>`).join('');
 const details=`<div class="note-box"><strong>${E(item.titulo)}</strong><br>${E(item.descripcion)}<br><span class="small">${E(item.direccion)}, ${E(item.comuna)} · ${priorityPill(item.prioridad)}</span><br>Estado actual: ${E(label(item.estado))} · Brigada: ${E(item.brigada??'Sin asignar')} · Informe final: ${item.tiene_informe?'recibido':'pendiente'}</div>`;
 if(!opts.length){showModal('Detalle de incidencia',details+'<p class="muted small">No hay una transición administrativa directa desde este estado. Si está en proceso, el jefe debe presentar el informe final antes de la revisión.</p><div class="modal-actions"><button class="btn primary" data-action="close-modal">Cerrar</button></div>');return;}
 showModal('Gestionar incidencia',`${details}<form id="incident-form" data-id="${E(id)}"><div class="form-grid"><div><label class="form-label">Nuevo estado permitido</label><select class="select" id="new-incident-state" name="nuevo">${selectOpts}</select></div><div id="choose-brigade" style="display:${opts[0]==='asignado'?'block':'none'}"><label class="form-label">Brigada disponible</label><select class="select" name="brigada"><option value="">Elige una brigada</option>${brigades.filter(b=>b.disponible).map(b=>`<option value="${E(b.id)}">${E(b.nombre)} · ${E(b.comuna)}</option>`).join('')}</select></div><div><label class="form-label">Observación o motivo</label><textarea name="comentario" placeholder="Escribe una observación para el historial (mínimo 5 caracteres en cierres, devoluciones o descartes)"></textarea></div></div><div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cancelar</button><button class="btn primary" type="submit">Guardar cambio</button></div></form>`,{type:'incident'});
}
function openActivity(id){const item=state.data.jornadas?.rows?.items?.find(x=>x.id===id);if(!item)return;const next=item.estado==='programada'?'en_curso':item.estado==='en_curso'?'finalizada':null;
 showModal('Actualizar jornada',`<div class="note-box"><strong>${E(item.titulo)}</strong><br>${E(item.brigada)} · ${date(item.fecha_inicio)}<br>Estado actual: ${E(label(item.estado))}</div>${next?`<form id="activity-form" data-id="${E(id)}" data-next="${E(next)}"><p>¿Confirmas pasar la jornada a <strong>${E(label(next))}</strong>?</p><div class="modal-actions"><button type="button" class="btn" data-action="close-modal">Cancelar</button><button type="submit" class="btn primary">Confirmar cambio</button></div></form>`:'<div class="modal-actions"><button class="btn" data-action="close-modal">Cerrar</button></div>'}`);
}
async function changeBrigadeState(id){const b=state.data.brigadas?.rows?.items?.find(x=>x.id===id);if(!b)return;const nuevo=b.estado==='abierta'?'cerrada':'abierta';if(!confirm(`¿Cambiar "${b.nombre}" a estado ${nuevo}?`))return;await mutate('eco_admin_estado_brigada',{p_brigada:id,p_estado:nuevo},'Estado de la brigada actualizado');}
async function changeRequest(id,yes){if(!confirm(`¿${yes?'Aceptar':'Rechazar'} esta solicitud de ingreso?`))return;await mutate('eco_admin_resolver_solicitud',{p_solicitud:id,p_aceptar:yes},yes?'Solicitud aceptada':'Solicitud rechazada')}
async function mutate(name,args,message,callback){try{await rpc(name,args);toast(message);dismissModal();if(callback)await callback();await loadData(false)}catch(err){toast(err.message,true);console.error(err)}}
function exportCsv(){const s=state.data.estadisticas?.stats;if(!s)return;
 const rows=[['Indicador','Valor'],...Object.entries(s).filter(([k,v])=>typeof v==='number'||typeof v==='string').map(([k,v])=>[k,v])];
 rows.push(['',''],['Estado de incidencias','Cantidad'],...(s.estados??[]).map(r=>[r.nombre,r.cantidad]));rows.push(['',''],['Tipo de residuo','Cantidad'],...(s.tipos??[]).map(r=>[r.nombre,r.cantidad]));rows.push(['',''],['Comuna','Incidencias'],...(s.comunas??[]).map(r=>[r.nombre,r.cantidad]));
 const csv='\ufeff'+rows.map(row=>row.map(x=>'"'+String(x??'').replaceAll('"','""')+'"').join(';')).join('\r\n');const blob=new Blob([csv],{type:'text/csv;charset=utf-8'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='EcoBrigada_Estadisticas_'+new Date().toISOString().slice(0,10)+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),3000);
}

// Eventos por delegación: las tablas se reconstruyen después de cada actualización.
document.addEventListener('click',async ev=>{
 if(ev.target.id==='modal-root'){dismissModal();return;}
 const view=ev.target.closest('[data-view]');if(view){await navigate(view.dataset.view);return;}
 const el=ev.target.closest('[data-action]');if(!el)return;
 const action=el.dataset.action,id=el.dataset.id;
 if(action==='logout'){await db.auth.signOut();return;}
 if(action==='menu'){$('#sidebar')?.classList.toggle('open');return;}
 if(action==='refresh'){await loadData();return;}
 if(action==='close-modal'){dismissModal();return;}
 if(action==='reset'){state.filter[state.view]={};state.pages[state.view]=0;await loadData();return;}
 if(action==='prev'||action==='next'){state.pages[state.view]=Math.max(0,(state.pages[state.view]??0)+(action==='next'?30:-30));await loadData();return;}
 if(action==='eco-tab'){state.filter.ecoanalisis={sub:id};state.pages.ecoanalisis=0;await loadData();return;}
 if(action==='export-stats'){exportCsv();return;}
 if(action==='role'){await openRole(id);return;}
 if(action==='delete-user'){await openDeleteUser(id);return;}
 if(action==='leader'){await openLeader(id);return;}
 if(action==='members'){await openMembers(id);return;}
 if(action==='brigade-state'){await changeBrigadeState(id);return;}
 if(action==='remove-member'){if(!confirm('¿Retirar este integrante de la brigada?'))return;await mutate('eco_admin_quitar_miembro',{p_brigada:el.dataset.brigade,p_usuario:id},'Integrante retirado',async()=>await openMembers(el.dataset.brigade));return;}
 if(action==='incident'){await openIncident(id);return;}
 if(action==='activity'){openActivity(id);return;}
 if(action==='request-yes'||action==='request-no'){await changeRequest(id,action==='request-yes');return;}
});
document.addEventListener('submit',async ev=>{
 const form=ev.target;ev.preventDefault();
 if(form.id==='login-form'){await login(form);return;}
 if(form.id==='filter-form'){state.filter[state.view]={...state.filter[state.view],buscar:form.elements.buscar?.value.trim()??'',estado:form.elements.estado?.value??''};state.pages[state.view]=0;await loadData();return;}
 if(form.id==='delete-user-form'){await deleteUserFromPanel(form);return;}
 if(form.id==='change-role-form'){await mutate('eco_admin_cambiar_rol',{p_usuario:form.dataset.id,p_rol:form.elements.rol.value},'Rol actualizado correctamente');return;}
 if(form.id==='change-leader-form'){if(!form.elements.usuario.value)return toast('Selecciona un líder',true);await mutate('eco_admin_cambiar_lider',{p_brigada:form.dataset.id,p_usuario:form.elements.usuario.value},'Líder asignado');return;}
 if(form.id==='add-member-form'){if(!form.elements.usuario.value)return toast('Selecciona un usuario',true);await mutate('eco_admin_agregar_miembro',{p_brigada:form.dataset.id,p_usuario:form.elements.usuario.value},'Integrante agregado');return;}
 if(form.id==='incident-form'){const nuevo=form.elements.nuevo.value,brigada=form.elements.brigada.value||null,comentario=form.elements.comentario.value.trim();if(nuevo==='asignado'&&!brigada)return toast('Selecciona una brigada disponible',true);if((['cerrado','descartado'].includes(nuevo)||novoDevuelve(form.dataset.id,nuevo))&&comentario.length<5)return toast('Debes escribir una observación de al menos 5 caracteres',true);await mutate('eco_admin_accion_incidencia',{p_id:form.dataset.id,p_nuevo:nuevo,p_brigada:brigada,p_comentario:comentario},'Incidencia actualizada');return;}
 if(form.id==='activity-form'){await mutate('eco_admin_accion_jornada',{p_jornada:form.dataset.id,p_estado:form.dataset.next},'Jornada actualizada');return;}
});
function novoDevuelve(id,nuevo){const i=state.data.incidencias?.rows?.items?.find(x=>x.id===id);return i?.estado==='en_revision'&&nuevo==='en_proceso'}
document.addEventListener('change',async ev=>{
 if(ev.target.id==='request-filter'){state.filter.solicitudes={estado:ev.target.value};state.pages.solicitudes=0;await loadData();return;}
 if(ev.target.id==='new-incident-state'){const c=$('#choose-brigade');if(c)c.style.display=ev.target.value==='asignado'?'block':'none';}
});
document.addEventListener('keydown',ev=>{if(ev.key==='Escape')dismissModal()});
init();
