#!/usr/bin/env node
// build_server.mjs - Local-only live build server for the /builder web page.
//
// Listens on 127.0.0.1 only. Accepts the same intent/lid/dimension/printer
// choices as `mastertray.py build`, runs it, and returns the resulting STL
// for download. A copy is also left in build/sandbox/output/.
//
// Usage:
//   node build/scripts/build_server.mjs [port]   (default port 5180)
//
// This is NOT meant to be exposed beyond localhost — it shells out to
// OpenSCAD with caller-supplied parameters.

import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PORT = Number(process.argv[2]) || 5180;

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const BUILD_DIR = path.resolve(SCRIPT_DIR, '..');
const REPO_ROOT = path.resolve(BUILD_DIR, '..');
const PYTHON = process.env.MASTERTRAY_PYTHON || 'python';
const SANDBOX_OUT = path.join(BUILD_DIR, 'sandbox', 'output');

const ALLOWED_ORIGIN = 'http://localhost:4321';

function sendJson(res, status, body) {
	res.writeHead(status, {
		'Content-Type': 'application/json',
		'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
	});
	res.end(JSON.stringify(body));
}

// Strip path separators and anything that isn't a safe filename character.
function sanitizeFilename(name, fallback) {
	const cleaned = String(name || '').replace(/[\\/:*?"<>|]+/g, '').trim();
	const base = cleaned || fallback;
	return base.toLowerCase().endsWith('.stl') ? base : `${base}.stl`;
}

function runMastertray(args) {
	return new Promise((resolve, reject) => {
		const proc = spawn(PYTHON, ['build/mastertray.py', 'build', ...args], { cwd: REPO_ROOT });
		let stderr = '';
		proc.stderr.on('data', (chunk) => { stderr += chunk; });
		proc.on('error', reject);
		proc.on('close', (code) => {
			if (code === 0) resolve();
			else reject(new Error(stderr || `mastertray.py exited with code ${code}`));
		});
	});
}

async function handleBuild(req, res) {
	let body = '';
	for await (const chunk of req) body += chunk;

	let params;
	try {
		params = JSON.parse(body);
	} catch {
		return sendJson(res, 400, { error: 'invalid JSON body' });
	}

	const { intent, lid, width, length, height, mode, slideDirection, slideCatch, printer, outName } = params;

	if (!intent) return sendJson(res, 400, { error: 'intent is required' });

	const args = ['--intent', intent];
	if (lid) args.push('--lid', lid);
	if (width) args.push('--width', String(width));
	if (length) args.push('--length', String(length));
	if (height) args.push('--height', String(height));
	if (mode) args.push('--mode', mode);
	if (slideDirection) args.push('--slide-direction', slideDirection);
	if (slideCatch) args.push('--slide-catch', slideCatch);

	await mkdir(SANDBOX_OUT, { recursive: true });
	const stlName = sanitizeFilename(outName, `${intent}_${Date.now()}`);
	const stlPath = path.join(SANDBOX_OUT, stlName);

	let tmpDir;
	try {
		// Write the requested printer settings to a temp override file so
		// mastertray.py's --config translation handles them.
		if (printer) {
			tmpDir = await mkdtemp(path.join(tmpdir(), 'mastertray-'));
			const printerYaml = [
				`filament: ${printer.filament ?? 'PLA'}`,
				`nozzle: ${printer.nozzle ?? 0.4}`,
				`layer_height: ${printer.layer_height ?? 0.28}`,
				`walls: ${printer.walls ?? 2}`,
				`fit: ${printer.fit ?? 'Standard'}`,
				'',
			].join('\n');
			const printerConfigPath = path.join(tmpDir, 'printer.yaml');
			await writeFile(printerConfigPath, printerYaml, 'utf-8');
			args.push('--config', printerConfigPath);
		}

		args.push('--out', stlPath);

		await runMastertray(args);

		const stl = await readFile(stlPath);
		res.writeHead(200, {
			'Content-Type': 'model/stl',
			'Content-Disposition': `attachment; filename="${stlName}"`,
			'X-Sandbox-Path': `build/sandbox/output/${stlName}`,
			'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
			'Access-Control-Expose-Headers': 'X-Sandbox-Path, Content-Disposition',
		});
		res.end(stl);
	} catch (err) {
		sendJson(res, 400, { error: String(err.message || err) });
	} finally {
		if (tmpDir) await rm(tmpDir, { recursive: true, force: true });
	}
}

async function handleReport(req, res) {
	const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
	const name = sanitizeFilename(url.searchParams.get('name') || '', 'unknown');
	const reportPath = path.join(SANDBOX_OUT, name.replace(/\.stl$/i, '.report.yaml'));
	try {
		const yaml = await readFile(reportPath, 'utf-8');
		res.writeHead(200, {
			'Content-Type': 'text/yaml; charset=utf-8',
			'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
		});
		res.end(yaml);
	} catch {
		sendJson(res, 404, { error: `report not found: ${name}` });
	}
}

const server = createServer((req, res) => {
	if (req.method === 'OPTIONS') {
		res.writeHead(204, {
			'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
			'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		});
		return res.end();
	}
	if (req.method === 'GET' && req.url === '/health') {
		return sendJson(res, 200, { ok: true });
	}
	if (req.method === 'GET' && req.url?.startsWith('/api/report')) {
		return handleReport(req, res);
	}
	if (req.method === 'POST' && req.url === '/api/build') {
		return handleBuild(req, res);
	}
	sendJson(res, 404, { error: 'not found' });
});

server.listen(PORT, '127.0.0.1', () => {
	console.log(`build server listening on http://127.0.0.1:${PORT} (local only)`);
	console.log(`STL output dir: ${SANDBOX_OUT}`);
});
