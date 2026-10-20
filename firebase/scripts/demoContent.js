// Contenido de ejemplo compartido por seedEmulator.js (local) y
// seedDemoContent.js (producción): el canal con la señal real y noticias
// ficticias de Ecuador.

const { Timestamp } = require("firebase-admin/firestore");

const PLAYBACK_URL = "http://190.107.232.9:8082/livestream/stream.m3u8";

// Noticias de ejemplo (ficticias), una o más por cada categoría de
// kNewsCategories (admin_panel/lib/news/news_item.dart).
const NEWS = [
  {
    category: "Local",
    featured: true,
    hoursAgo: 1,
    title: "Tulcán se prepara para el Festival de las Flores y la Frontera",
    summary: "Comerciantes y artesanos del Carchi alistan stands en el parque Ayora.",
    body: "La ciudad recibirá a visitantes de ambos lados de la frontera durante el fin de semana. " +
      "Habrá ferias gastronómicas con platos típicos carchenses, presentaciones de danza y una exposición de flores de la provincia.",
  },
  {
    category: "Local",
    hoursAgo: 5,
    title: "Mantenimiento vial en la vía Tulcán – El Ángel",
    summary: "Se prevén cierres parciales en horario diurno durante dos semanas.",
    body: "Los trabajos incluyen bacheo y limpieza de cunetas. Se recomienda a los conductores tomar precauciones " +
      "y respetar la señalización temporal colocada en los tramos intervenidos.",
  },
  {
    category: "Nacional",
    hoursAgo: 3,
    title: "Inicia el periodo de matrículas para el régimen Sierra-Amazonía",
    summary: "Las familias pueden registrar a los estudiantes en línea hasta fin de mes.",
    body: "El proceso se realiza en la plataforma del Ministerio de Educación. Para nuevos estudiantes se requiere " +
      "la cédula del representante y del alumno, además de un comprobante de domicilio.",
  },
  {
    category: "Nacional",
    hoursAgo: 26,
    title: "Quito y Guayaquil amplían horarios de transporte público por feriado",
    summary: "Más unidades circularán en las rutas de mayor demanda.",
    body: "Los municipios anunciaron frecuencias adicionales en terminales terrestres y corredores principales " +
      "para atender el flujo de viajeros durante el feriado nacional.",
  },
  {
    category: "Deportes",
    hoursAgo: 8,
    title: "La Tri convoca a sus jugadores para la próxima fecha eliminatoria",
    summary: "El cuerpo técnico incluyó a varios jóvenes del fútbol local.",
    body: "La selección ecuatoriana se concentrará en Quito una semana antes del partido. " +
      "Los aficionados podrán adquirir sus entradas a través de los canales oficiales de la federación.",
  },
  {
    category: "Deportes",
    hoursAgo: 30,
    title: "Ciclistas carchenses brillan en la Vuelta al Ecuador",
    summary: "Dos corredores de la provincia terminaron entre los diez primeros de la etapa.",
    body: "La etapa de montaña entre Ibarra y Tulcán fue una de las más exigentes de la competencia. " +
      "El público acompañó a los deportistas a lo largo del recorrido.",
  },
  {
    category: "Cultura",
    hoursAgo: 12,
    title: "El cementerio de Tulcán abre recorridos guiados nocturnos",
    summary: "Las esculturas en ciprés podrán apreciarse con una nueva iluminación.",
    body: "El recorrido dura aproximadamente una hora e incluye la historia del jardín escultórico, " +
      "uno de los atractivos turísticos más visitados del norte del país.",
  },
  {
    category: "Comunicados",
    hoursAgo: 18,
    title: "Corte programado de energía en sectores del norte de la ciudad",
    summary: "La suspensión será el sábado de 08:00 a 14:00.",
    body: "La empresa eléctrica realizará trabajos de mantenimiento en la red. " +
      "Se recomienda desconectar equipos sensibles antes del corte.",
  },
  {
    category: "Programación",
    hoursAgo: 48,
    title: "Nuevo noticiero estelar de lunes a viernes a las 19:00",
    summary: "CCTV CANAL 7 estrena su espacio informativo con lo más importante del Carchi y el país.",
    body: "El noticiero contará con secciones de deportes, cultura y entrevistas en vivo. " +
      "También podrá verse en directo desde esta aplicación.",
  },
];

// Parrilla de ejemplo (ficticia). days: 1 = lunes … 7 = domingo.
// end "00:00" = termina a medianoche.
const WEEKDAYS = [1, 2, 3, 4, 5];
const SCHEDULE = [
  { days: [1, 2, 3, 4, 5, 6, 7], start: "00:00", end: "06:00", title: "Madrugada musical", description: "Música continua para acompañar la noche." },
  { days: WEEKDAYS, start: "06:00", end: "08:00", title: "Buenos días Carchi", host: "Equipo de noticias", description: "Noticias, clima y estado de las vías para empezar el día." },
  { days: WEEKDAYS, start: "08:00", end: "10:00", title: "Música y saludos", host: "Cabina Fantástica", description: "Los éxitos del momento y saludos de la audiencia." },
  { days: WEEKDAYS, start: "10:00", end: "12:00", title: "Sabor carchense", description: "Recetas tradicionales de la provincia, paso a paso." },
  { days: WEEKDAYS, start: "12:00", end: "13:00", title: "Noticiero del mediodía", host: "Equipo de noticias", description: "Lo más importante de la mañana en el Carchi y el país." },
  { days: WEEKDAYS, start: "13:00", end: "16:00", title: "Tarde fantástica", host: "Cabina Fantástica", description: "Música variada, concursos y entrevistas." },
  { days: WEEKDAYS, start: "16:00", end: "18:00", title: "Zona deportiva", description: "Fútbol local, la Tri y los deportistas carchenses." },
  { days: WEEKDAYS, start: "18:00", end: "19:00", title: "Clásicos del recuerdo", description: "Pasillos, boleros y música nacional." },
  { days: WEEKDAYS, start: "19:00", end: "20:00", title: "Noticiero estelar", host: "Equipo de noticias", description: "El resumen informativo del día, con entrevistas en vivo." },
  { days: WEEKDAYS, start: "20:00", end: "22:00", title: "Cine en casa", description: "Una película para toda la familia." },
  { days: WEEKDAYS, start: "22:00", end: "00:00", title: "Noche romántica", host: "Cabina Fantástica", description: "Baladas para cerrar el día." },
  { days: [6], start: "07:00", end: "09:00", title: "Fin de semana en familia", description: "Agenda de eventos y planes para el fin de semana." },
  { days: [6], start: "09:00", end: "12:00", title: "Fútbol barrial", description: "Transmisión de los campeonatos de los barrios de Tulcán." },
  { days: [6], start: "12:00", end: "14:00", title: "Sábado de cumbia", host: "Cabina Fantástica" },
  { days: [6], start: "14:00", end: "18:00", title: "Tarde de películas" },
  { days: [6], start: "18:00", end: "22:00", title: "Fiesta fantástica", host: "Cabina Fantástica", description: "La previa del sábado con la mejor música." },
  { days: [7], start: "08:00", end: "10:00", title: "Misa dominical", description: "Transmisión de la misa desde Tulcán." },
  { days: [7], start: "10:00", end: "13:00", title: "Deportes en vivo", description: "Resultados y transmisiones deportivas del domingo." },
  { days: [7], start: "13:00", end: "18:00", title: "Domingo de música nacional" },
  { days: [7], start: "18:00", end: "22:00", title: "Cine dominical" },
];

// Agrega al batch el canal (streams/main), las noticias y la parrilla demo
// del tenant.
function addDemoContent(batch, tenantRef, name) {
  batch.set(tenantRef.collection("streams").doc("main"), {
    title: name,
    description: "Señal en vivo",
    status: "live",
    playbackUrl: PLAYBACK_URL,
    thumbnailUrl: null,
    startedAt: Timestamp.now(),
  });

  const now = Date.now();
  NEWS.forEach((n, i) => {
    const createdAt = Timestamp.fromMillis(now - n.hoursAgo * 3600 * 1000);
    batch.set(tenantRef.collection("news").doc(`ejemplo-${i + 1}`), {
      title: n.title,
      summary: n.summary,
      body: n.body,
      category: n.category,
      imageUrl: `https://picsum.photos/seed/canal7-${i + 1}/800/450`,
      featured: n.featured ?? false,
      published: true,
      createdAt,
      updatedAt: createdAt,
    });
  });

  SCHEDULE.forEach((s, i) => {
    batch.set(tenantRef.collection("schedule").doc(`programa-${i + 1}`), {
      title: s.title,
      host: s.host ?? "",
      description: s.description ?? "",
      days: s.days,
      start: s.start,
      end: s.end,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
}

module.exports = { addDemoContent };
