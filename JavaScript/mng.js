const MNG = (() => {
    const PNG_SIG = new Uint8Array([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
    const MNG_SIG = new Uint8Array([0x8A,0x4D,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
    function readChunks(buf) {
        const data = new Uint8Array(buf), view = new DataView(buf);
        for (let i = 0; i < 8; i++) if (data[i] !== MNG_SIG[i]) {
            throw new Error(`Not MNG (sig: ${Array.from(data.slice(0,8)).map(b=>b.toString(16).padStart(2,'0')).join(' ')})`);
        }
        const chunks = []; let pos = 8;
        while (pos < data.length) {
            if (data.length - pos < 12) throw new Error('Truncated chunk');
            const len = view.getUint32(pos), type = String.fromCharCode(data[pos+4],data[pos+5],data[pos+6],data[pos+7]);
            if (len > data.length - pos - 12) throw new Error('Invalid chunk length');
            chunks.push({ type, len, data: data.subarray(pos+8, pos+8+len), offset: pos });
            pos += len + 12;
        }
        return chunks;
    }
    function parseFRAM(d) {
        let pos = 1;
        while (pos < d.length && d[pos]) pos++;
        pos++;
        if (pos + 4 > d.length) return null;
        const mode = d[pos]; pos += 4;
        if (!mode || pos + 4 > d.length) return null;
        return { mode, ticks: new DataView(d.buffer, d.byteOffset + pos).getUint32(0) };
    }
    async function parse(src) {
        const buf = src instanceof ArrayBuffer ? src : await src.arrayBuffer();
        const raw = new Uint8Array(buf), chunks = readChunks(buf);
        let ticksPerSec = 100, defaultTicks = null, nextTicks = null, frameParts = [], inPNG = false;
        const frames = [];
        for (const c of chunks) {
            if (c.type === 'MHDR') { if (c.len < 28) throw new Error('Invalid MHDR'); const t = new DataView(c.data.buffer, c.data.byteOffset).getUint32(8); if (t > 0) ticksPerSec = t; }
            else if (c.type === 'FRAM') { const f = parseFRAM(c.data); if (f?.mode === 1) nextTicks = f.ticks; else if (f?.mode === 2) { defaultTicks = f.ticks; nextTicks = null; } }
            if (!inPNG && c.type === 'IHDR') { frameParts = []; inPNG = true; }
            if (inPNG) {
                frameParts.push(c);
                if (c.type === 'IEND') {
                    inPNG = false;
                    const png = new Uint8Array(8 + frameParts.reduce((s,x) => s + x.len + 12, 0));
                    png.set(PNG_SIG); let p = 8;
                    for (const f of frameParts) { png.set(raw.subarray(f.offset, f.offset + f.len + 12), p); p += f.len + 12; }
                    const ticks = nextTicks ?? defaultTicks, n = ticks * 1000 + (ticksPerSec >>> 1);
                    frames.push({ png, delay: ticks === null ? 100 : Math.min(4294967295, (n - n % ticksPerSec) / ticksPerSec) }); nextTicks = null;
                }
            }
        }
        if (inPNG || !frames.length) throw new Error('No complete frames');
        return frames;
    }
    function loadImages(frames) {
        return Promise.all(frames.map(f => new Promise((res, rej) => {
            const img = new Image(), url = URL.createObjectURL(new Blob([f.png], { type: 'image/png' }));
            img.onload = () => { URL.revokeObjectURL(url); res({ img, delay: f.delay }); };
            img.onerror = () => { URL.revokeObjectURL(url); rej(new Error('Frame decode failed')); };
            img.src = url;
        })));
    }
    function makeCanvas(frames) {
        const canvas = document.createElement('canvas');
        canvas.width = frames[0].img.width; canvas.height = frames[0].img.height;
        const ctx = canvas.getContext('2d');
        let idx = 0, timer = null, running = false;
        const draw = () => { ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.drawImage(frames[idx].img, 0, 0); };
        const tick = () => { draw(); timer = setTimeout(() => { if (!canvas.isConnected) { running = false; return; } idx = (idx + 1) % frames.length; tick(); }, Math.min(frames[idx].delay, 2147483647)); };
        canvas.play  = () => { if (!running) { running = true; tick(); } };
        canvas.pause = () => { clearTimeout(timer); running = false; };
        canvas.stop  = () => { canvas.pause(); idx = 0; draw(); };
        draw(); return canvas;
    }
    async function play(src, autoplay = true) {
        const frames = await parse(src);
        const loaded = await loadImages(frames);
        const canvas = makeCanvas(loaded);
        if (autoplay && loaded.length > 1) canvas.play();
        return canvas;
    }
    async function toBlob(src) {
        const frames = await parse(src);
        return new Blob([frames[0].png], { type: 'image/png' });
    }
    return { play, parse, toBlob };
})();
