// Endereço do servidor.
//
// Vazio = usa o mesmo servidor que entregou esta página. É o caso quando você
// abre localhost:8000, ou quando a página está hospedada no próprio Render.
//
// Preencha só se for hospedar esta página em outro lugar — no seu site, por
// exemplo. Aí ponha o endereço do servidor:
//
//     const SERVIDOR = "wss://nao-consigo-tirar-voce.onrender.com";
//
const SERVIDOR = "";

// ---------------------------------------------------------------- arquivo
//
// Modo arquivo: preencha com o nome de um JSON de performance e a página
// passa a tocar SÓ aquilo, em repetição, sem servidor nenhum.
//
//     const ARQUIVO = "performance-2026-08-09.json";
//
// É assim que o registro vive no seu site: quatro arquivos estáticos
// (index.html, style.css, script.js e o JSON) numa pasta do cPanel.
// Nada de Python, nada de WebSocket, nada que possa cair.
//
const ARQUIVO = "";

// Qual performance a página repete quando não há ninguém sendo seguido.
// Vazio = a mais recente. Preenchido = sempre esta, ignorando os testes
// que vierem depois.
const SESSAO = "2026-08-10_22h19m35s";

// Fuso da performance, em horas. O servidor roda em UTC, mas o registro
// tem que mostrar sempre a hora do lugar onde aconteceu — senão quem lê
// de outro país vê outro horário, e deixa de ser documentação.
const FUSO_HORAS = -3;

// Quantos versos manter na página antes de descartar os mais antigos.
const MAX_BLOCOS = 400;

// No modo registro, o intervalo original entre os versos é respeitado, mas
// nunca passa disto — senão uma pausa longa da performance trava a leitura.
const PAUSA_MAXIMA = 8000;
const PAUSA_MINIMA = 400;

// ---------------------------------------------------------------- satélite
//
// A imagem não é baixada nem guardada: o registro guarda a coordenada e o
// navegador busca a vista na hora de exibir. Custo zero de armazenamento, e
// na repetição a imagem refaz a caminhada sozinha.
//
// Padrão: Esri World Imagery — satélite, sem chave, sem cadastro.
// Para trocar por Google ou Mapbox, é só reescrever montarVista().
//
const VISTA_ATIVA = true;

// Meio-lado da área mostrada, em graus. 0.0012 ≈ 130 metros de lado.
// Aumentar afasta a câmera e revela menos.
const VISTA_RAIO = 0.0012;

// Só busca imagem nova se ele andou mais que isto (graus ≈ 11 m).
const VISTA_LIMIAR = 0.0001;

// Intervalo mínimo entre duas buscas, em milissegundos.
const VISTA_INTERVALO = 10000;

const texto = document.getElementById("texto");
const conexao = document.getElementById("conexao");
const cabecalho = document.getElementById("registro");

const campos = {};

document.querySelectorAll("[data-campo]").forEach(el => {
    campos[el.dataset.campo] = el;
});

const anterioresValores = {};

let ultimoTimestamp = null;
// Guardamos os versos como dados, não só como pixels: trocar de língua
// redesenha a coluna inteira a partir daqui, sem pedir nada ao servidor.
const versosNaTela = [];
let ultimoEstado = null;

function redesenharVersos() {

    texto.textContent = "";

    if (!versosNaTela.length) {
        texto.classList.add("vazio");
        texto.textContent = lingua === "en" ? "waiting" : "aguardando";
        return;
    }

    texto.classList.remove("vazio");

    versosNaTela.forEach(v => desenhar(v.pt, v.en, v.epoch, false));
}

let aoVivo = false;
let repeticao = null;

// ------------------------------------------------------------- horário

function base(url) {

    if (SERVIDOR) {
        const limpo = SERVIDOR.trim().replace(/\/+$/, "");
        const http = limpo.includes("://")
            ? limpo.replace(/^ws/, "http")
            : "https://" + limpo;
        return http + url;
    }

    return url;
}

function noFuso(epochOuIso) {

    const ms = typeof epochOuIso === "number"
        ? epochOuIso * 1000
        : Date.parse(epochOuIso);

    return new Date(ms + FUSO_HORAS * 3600 * 1000);
}

function hora(epoch) {

    if (!epoch) return "--:--:--";

    const d = noFuso(epoch);

    const p = n => String(n).padStart(2, "0");

    return `${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())}`;
}

const MESES = {
    pt: ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
         "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"],
    en: ["January", "February", "March", "April", "May", "June",
         "July", "August", "September", "October", "November", "December"]
};

function dataPorExtenso(iso) {

    const d = noFuso(iso);
    const mes = MESES[lingua][d.getUTCMonth()];

    return lingua === "en"
        ? `${d.getUTCDate()} ${mes} ${d.getUTCFullYear()}`
        : `${d.getUTCDate()} de ${mes} de ${d.getUTCFullYear()}`;
}

function horaCurta(iso) {
    const d = noFuso(iso);
    return `${d.getUTCHours()}h${String(d.getUTCMinutes()).padStart(2, "0")}`;
}

// ------------------------------------------------------------- formatação

function formatar(chave, valor) {

    if (valor === null || valor === undefined) return "—";

    if (typeof valor === "boolean") return valor ? "sim" : "não";

    if (typeof valor === "string") return valor.toLowerCase();

    if (typeof valor !== "number") return String(valor);

    if (!isFinite(valor)) return "—";

    switch (chave) {

        case "batteryLevel":
        case "brightness":
        case "volume":
            return Math.round(valor * 100) + "%";

        case "steps":
        case "floorsAscended":
        case "floorsDescended":
        case "visitCount":
        case "nearbyDevices":
        case "contactCount":
            return String(Math.round(valor));

        case "minutesHere":
            return Math.round(valor) + " min";

        case "voiceRatio":
            return Math.round(valor * 100) + "%";

        case "absoluteAltitude":
            return Math.round(valor) + " m";

        case "headYaw":
        case "headPitch":
            return (valor * 180 / Math.PI).toFixed(0) + "°";

        case "distance":
            return Math.round(valor) + " m";

        case "cadence":
            return valor.toFixed(2);

        case "pitch":
        case "roll":
        case "yaw":
            return (valor * 180 / Math.PI).toFixed(0) + "°";

        case "latitude":
        case "longitude":
            return valor.toFixed(4);

        case "heading":
        case "course":
            return Math.round(valor) + "°";

        case "altitude":
        case "relativeAltitude":
        case "speed":
        case "microphoneLevel":
            return valor.toFixed(1);

        case "pressure":
            return valor.toFixed(2);

        default:
            return valor.toFixed(3);
    }
}

// ------------------------------------------------------------- satélite

const vista = document.getElementById("vista");
const satelite = document.getElementById("satelite");

let vistaUltimaLat = null;
let vistaUltimaLon = null;
let vistaUltimoInstante = 0;

function montarVista(lat, lon) {

    const r = VISTA_RAIO;

    const bbox = [lon - r, lat - r, lon + r, lat + r].join(",");

    return "https://server.arcgisonline.com/arcgis/rest/services/"
        + "World_Imagery/MapServer/export"
        + `?bbox=${bbox}&bboxSR=4326&imageSR=3857`
        + "&size=450,450&format=jpg&transparent=false&f=image";
}

function atualizarVista(estado) {

    if (!VISTA_ATIVA || !estado) return;

    const lat = estado.latitude;
    const lon = estado.longitude;

    if (typeof lat !== "number" || typeof lon !== "number") return;
    if (lat === 0 && lon === 0) return;

    const agora = Date.now();

    if (agora - vistaUltimoInstante < VISTA_INTERVALO) return;

    // Parado, a mesma imagem serve. Só busca de novo quando ele anda.
    if (vistaUltimaLat !== null) {

        const andou =
            Math.abs(lat - vistaUltimaLat) > VISTA_LIMIAR ||
            Math.abs(lon - vistaUltimaLon) > VISTA_LIMIAR;

        if (!andou) return;
    }

    vistaUltimaLat = lat;
    vistaUltimaLon = lon;
    vistaUltimoInstante = agora;

    const nova = new Image();

    nova.onload = () => {
        satelite.src = nova.src;
        satelite.classList.add("visivel");
        vista.style.display = "block";
        vista.classList.add("ativa");
    };

    nova.src = montarVista(lat, lon);
}

function pintarSensores(estado, forcar = false) {

    if (!estado) return;

    ultimoEstado = estado;

    atualizarVista(estado);

    for (const chave in campos) {

        const bruto = estado[chave];
        const formatado = traduzirValor(formatar(chave, bruto));
        const el = campos[chave];

        if (!forcar && el.textContent === formatado) continue;

        el.textContent = formatado;

        if (anterioresValores[chave] !== undefined) {
            el.classList.add("mudou");
            requestAnimationFrame(() => {
                requestAnimationFrame(() => el.classList.remove("mudou"));
            });
        }

        anterioresValores[chave] = bruto;
    }
}

// ------------------------------------------------------------- versos

function perto(margem = 140) {
    const distancia = document.body.scrollHeight - window.scrollY - window.innerHeight;
    return distancia < margem;
}

function limpar() {
    texto.textContent = "";
    texto.classList.remove("vazio");
    versosNaTela.length = 0;
}

function acrescentar(trecho, epoch, animar = true, trechoEn = null) {

    if (!trecho) return;

    const limpo = trecho.trim();

    if (!limpo) return;

    versosNaTela.push({ pt: limpo, en: trechoEn, epoch: epoch });

    while (versosNaTela.length > MAX_BLOCOS) versosNaTela.shift();

    desenhar(limpo, trechoEn, epoch, animar);
}

function desenhar(limpo, trechoEn, epoch, animar) {

    const seguir = perto();

    if (texto.classList.contains("vazio")) limpar();

    // Sem tradução gravada, o verso aparece em português mesmo em inglês.
    const corpo = (lingua === "en" && trechoEn) ? trechoEn : limpo;

    // Uma resposta pode trazer até três versos. Todos vieram do mesmo
    // instante, então só o primeiro leva o carimbo — como uma mensagem só.
    const versos = corpo.split("\n").map(v => v.trim()).filter(Boolean);

    versos.forEach((linha, i) => {

        const marca = document.createElement("span");
        marca.className = "hora";
        marca.textContent = i === 0 ? `[${hora(epoch)}]` : "";

        const verso = document.createElement("span");
        verso.className = "verso";
        verso.textContent = linha;

        if (!animar) {
            marca.style.animation = "none";
            verso.style.animation = "none";
        }

        texto.appendChild(marca);
        texto.appendChild(verso);
    });

    while (texto.children.length > MAX_BLOCOS * 2) {
        texto.firstElementChild.remove();
        texto.firstElementChild.remove();
    }

    if (seguir) {
        window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
    }
}

// ------------------------------------------------------------- registro

function anunciar(html) {
    cabecalho.innerHTML = html;
    cabecalho.style.display = html ? "block" : "none";
}

// A sessão fica guardada para que a legenda possa ser reescrita quando a
// língua muda — antes ela era montada uma vez e congelava em português.
let sessaoAtual = null;

function escreverLegenda() {

    if (!sessaoAtual) return;

    const quando = dataPorExtenso(sessaoAtual.inicio);
    const de = horaCurta(sessaoAtual.inicio);
    const ate = sessaoAtual.fim ? horaCurta(sessaoAtual.fim) : "?";
    const n = sessaoAtual.linhas;

    const ponto = " &nbsp;·&nbsp; ";

    anunciar(
        lingua === "en"
            ? `record of the performance of ${quando}, ${de} to ${ate}`
              + ponto + `${n} lines` + ponto + "looping"
            : `registro da performance de ${quando}, das ${de} às ${ate}`
              + ponto + `${n} versos` + ponto + "em repetição"
    );
}

function pararRepeticao() {
    if (repeticao) {
        clearTimeout(repeticao);
        repeticao = null;
    }
}

async function tocarRegistro() {

    let gravacao;

    const endereco = ARQUIVO
        ? ARQUIVO
        : base(SESSAO ? `/registro/${SESSAO}` : "/registro/ultima");

    try {
        const r = await fetch(endereco);
        gravacao = await r.json();
    } catch {
        anunciar(lingua === "en" ? "could not load the record"
                            : "não foi possível carregar o registro");
        return;
    }

    if (gravacao && gravacao.erro) {
        anunciar(lingua === "en" ? "performance not found"
                                 : "performance não encontrada");
        return;
    }

    if (!gravacao || !gravacao.linhas || !gravacao.linhas.length) {
        anunciar(lingua === "en" ? "no performance recorded yet"
                                 : "nenhuma performance registrada ainda");
        return;
    }

    const sessao = gravacao.sessao;
    const linhas = gravacao.linhas;

    sessaoAtual = sessao;
    escreverLegenda();

    let i = 0;

    limpar();

    function proximo() {

        if (aoVivo) return;

        const linha = linhas[i];

        acrescentar(linha.texto, linha.epoch, true, linha.texto_en);

        if (linha.estado) pintarSensores(linha.estado);

        const seguinte = linhas[i + 1];

        let espera = 6000;

        if (seguinte) {
            espera = (seguinte.epoch - linha.epoch) * 1000;
        }

        espera = Math.max(PAUSA_MINIMA, Math.min(espera, PAUSA_MAXIMA));

        i += 1;

        if (i >= linhas.length) {
            i = 0;
            espera = 4000;
            repeticao = setTimeout(() => { limpar(); proximo(); }, espera);
            return;
        }

        repeticao = setTimeout(proximo, espera);
    }

    proximo();
}

function entrarAoVivo() {

    if (aoVivo) return;

    aoVivo = true;
    pararRepeticao();
    limpar();
    sessaoAtual = null;
    anunciar("");
}

// ------------------------------------------------------------- conexão

let socket = null;
let tentativa = 0;

function marcarConexao(online) {
    conexao.dataset.estado = online ? "online" : "offline";
    conexao.textContent = conexao.dataset.estado;
    conexao.className = "valor " + (online ? "online" : "offline");
}

function enderecoDoSocket() {

    if (SERVIDOR) {

        const limpo = SERVIDOR.trim().replace(/\/+$/, "");

        const b = limpo.includes("://")
            ? limpo.replace(/^http/, "ws")
            : "wss://" + limpo;

        return b + "/ws/web";
    }

    const protocolo = location.protocol === "https:" ? "wss:" : "ws:";

    return `${protocolo}//${location.host}/ws/web`;
}

function conectar() {

    socket = new WebSocket(enderecoDoSocket());

    socket.onopen = () => {
        tentativa = 0;
        marcarConexao(true);
    };

    socket.onmessage = evento => {

        let dados;

        try {
            dados = JSON.parse(evento.data);
        } catch {
            return;
        }

        if (dados.type === "bootstrap") {

            if (dados.ao_vivo) {

                entrarAoVivo();

                (dados.history || []).forEach(
                    item => acrescentar(item.text, item.timestamp, false, item.text_en)
                );

                acrescentar(dados.text, dados.timestamp, false, dados.text_en);
                ultimoTimestamp = dados.timestamp;

                pintarSensores(dados.state);

            } else {
                aoVivo = false;
                tocarRegistro();
            }

            return;
        }

        if (dados.type === "update") {

            entrarAoVivo();

            // O modelo pode voltar a um verso quase igual, então não dá para
            // filtrar por texto. O timestamp garante uma entrada por geração.
            if (dados.timestamp !== ultimoTimestamp) {
                ultimoTimestamp = dados.timestamp;
                acrescentar(dados.text, dados.timestamp, true, dados.text_en);
            }

            pintarSensores(dados.state);
            return;
        }

        if (dados.type === "sensors") {
            if (aoVivo) pintarSensores(dados.state);
            return;
        }

        if (dados.type === "fim") {
            // A performance acabou: a página vira arquivo.
            aoVivo = false;
            ultimoTimestamp = null;
            tocarRegistro();
        }
    };

    socket.onclose = () => {
        marcarConexao(false);
        tentativa += 1;
        const espera = Math.min(1000 * 2 ** tentativa, 15000);
        setTimeout(conectar, espera);
    };

    socket.onerror = () => socket.close();
}

// No modo arquivo a página nunca conecta em servidor nenhum: ela só toca
// o JSON e repete para sempre.
if (ARQUIVO) {
    conexao.textContent = "registro";
    conexao.className = "valor";
    tocarRegistro();
} else {
    conectar();
}

// ------------------------------------------------------------- sobre

// A sinopse nasce fechada: quem chega vê o poema primeiro, e abre o texto
// se quiser saber o que está lendo.
const botaoSobre = document.getElementById("sobre");
const sinopse = document.getElementById("sinopse");

if (botaoSobre && sinopse) {

    botaoSobre.addEventListener("click", () => {

        const estavaAberta = !sinopse.hidden;

        sinopse.hidden = estavaAberta;
        botaoSobre.setAttribute("aria-expanded", String(!estavaAberta));
        botaoSobre.textContent = estavaAberta ? "sobre" : "fechar";
    });
}

// ------------------------------------------------------------- língua

// O português é o poema; o inglês é documentação dele. Quando um verso não
// tem tradução gravada, aparece em português mesmo na versão inglesa — é o
// que um catálogo bilíngue faz, e é honesto.
let lingua = "pt";

try {
    const guardada = localStorage.getItem("lingua");
    if (guardada === "pt" || guardada === "en") lingua = guardada;
} catch {}

// Valores que o aparelho manda já escritos em português.
const VALORES_EN = {
    "sim": "yes", "não": "no",
    "parado": "still", "andando": "walking", "correndo": "running",
    "de bicicleta": "cycling", "em veículo": "in a vehicle",
    "desconhecida": "unknown",
    "alta": "high", "média": "medium", "baixa": "low",
    "carregando": "charging", "completa": "full", "na bateria": "on battery",
    "normal": "normal", "morno": "warm", "quente": "hot",
    "muito quente": "very hot",
    "wi-fi": "wi-fi", "celular": "cellular", "cabo": "wired",
    "sem rede": "no network", "outra": "other",
    "chegou": "arrived", "saiu": "left",
    "portrait": "portrait", "portrait invertido": "portrait upside down",
    "landscape esquerda": "landscape left", "landscape direita": "landscape right",
    "tela para cima": "face up", "tela para baixo": "face down"
};

function traduzirValor(texto) {
    if (lingua !== "en") return texto;
    const chave = String(texto).toLowerCase();
    return VALORES_EN[chave] !== undefined ? VALORES_EN[chave] : texto;
}

function aplicarLingua() {

    document.documentElement.lang = lingua === "en" ? "en" : "pt-BR";

    document.querySelectorAll("[data-pt][data-en]").forEach(el => {
        const novo = el.dataset[lingua];
        if (novo !== undefined && el.id !== "sobre") el.textContent = novo;
    });

    // O botão "sobre" muda de rótulo conforme está aberto ou fechado.
    if (botaoSobre && sinopse) {
        const aberta = !sinopse.hidden;
        botaoSobre.textContent = aberta
            ? (lingua === "en" ? "close" : "fechar")
            : botaoSobre.dataset[lingua];
    }

    document.querySelectorAll("#sinopse [lang]").forEach(bloco => {
        bloco.hidden = bloco.getAttribute("lang") !== lingua;
    });

    document.querySelectorAll(".lingua").forEach(b => {
        b.classList.toggle("ativa", b.dataset.lingua === lingua);
    });

    if (conexao.dataset.estado) {
        conexao.textContent = lingua === "en"
            ? conexao.dataset.estado
            : (conexao.dataset.estado === "online" ? "online" : "offline");
    }

    // Os valores dos sensores precisam ser reescritos na língua nova.
    for (const chave in anterioresValores) delete anterioresValores[chave];
    if (ultimoEstado) pintarSensores(ultimoEstado, true);

    escreverLegenda();
    redesenharVersos();
}

document.querySelectorAll(".lingua").forEach(botao => {
    botao.addEventListener("click", () => {
        lingua = botao.dataset.lingua;
        try { localStorage.setItem("lingua", lingua); } catch {}
        aplicarLingua();
    });
});

aplicarLingua();
