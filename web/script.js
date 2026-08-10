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

// Quantos versos manter na página antes de descartar os mais antigos.
const MAX_BLOCOS = 400;

// No modo registro, o intervalo original entre os versos é respeitado, mas
// nunca passa disto — senão uma pausa longa da performance trava a leitura.
const PAUSA_MAXIMA = 8000;
const PAUSA_MINIMA = 400;

const texto = document.getElementById("texto");
const conexao = document.getElementById("conexao");
const cabecalho = document.getElementById("registro");

const campos = {};

document.querySelectorAll("[data-campo]").forEach(el => {
    campos[el.dataset.campo] = el;
});

const anterioresValores = {};

let ultimoTimestamp = null;
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

function hora(epoch) {

    if (!epoch) return "--:--:--";

    const d = new Date(epoch * 1000);

    const p = n => String(n).padStart(2, "0");

    return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function dataPorExtenso(iso) {

    const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];

    const d = new Date(iso);

    return `${d.getDate()} de ${meses[d.getMonth()]} de ${d.getFullYear()}`;
}

function horaCurta(iso) {
    const d = new Date(iso);
    return `${d.getHours()}h${String(d.getMinutes()).padStart(2, "0")}`;
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

function pintarSensores(estado) {

    if (!estado) return;

    for (const chave in campos) {

        const bruto = estado[chave];
        const formatado = formatar(chave, bruto);
        const el = campos[chave];

        if (el.textContent === formatado) continue;

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
}

function acrescentar(trecho, epoch, animar = true) {

    if (!trecho) return;

    const limpo = trecho.trim();

    if (!limpo) return;

    const seguir = perto();

    if (texto.classList.contains("vazio")) limpar();

    // Uma resposta pode trazer até três versos. Todos vieram do mesmo
    // instante, então só o primeiro leva o carimbo — como uma mensagem só.
    const versos = limpo.split("\n").map(v => v.trim()).filter(Boolean);

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

function pararRepeticao() {
    if (repeticao) {
        clearTimeout(repeticao);
        repeticao = null;
    }
}

async function tocarRegistro() {

    let gravacao;

    try {
        const r = await fetch(ARQUIVO ? ARQUIVO : base("/registro/ultima"));
        gravacao = await r.json();
    } catch {
        anunciar("não foi possível carregar o registro");
        return;
    }

    if (!gravacao || !gravacao.linhas || !gravacao.linhas.length) {
        anunciar("nenhuma performance registrada ainda");
        return;
    }

    const sessao = gravacao.sessao;
    const linhas = gravacao.linhas;

    const inicio = dataPorExtenso(sessao.inicio);
    const de = horaCurta(sessao.inicio);
    const ate = sessao.fim ? horaCurta(sessao.fim) : "?";

    anunciar(
        `registro da performance de ${inicio}, das ${de} às ${ate} &nbsp;·&nbsp; ` +
        `${sessao.linhas} versos &nbsp;·&nbsp; em repetição`
    );

    let i = 0;

    limpar();

    function proximo() {

        if (aoVivo) return;

        const linha = linhas[i];

        acrescentar(linha.texto, linha.epoch, true);

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
    anunciar("");
}

// ------------------------------------------------------------- conexão

let socket = null;
let tentativa = 0;

function marcarConexao(online) {
    conexao.textContent = online ? "online" : "offline";
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
                    item => acrescentar(item.text, item.timestamp, false)
                );

                acrescentar(dados.text, dados.timestamp, false);
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
                acrescentar(dados.text, dados.timestamp);
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
