import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import worker, { RuntimeCoordinator } from "../src/index.js";

const token = "unit-test-agent-token";
const canonicalOauthOrigin = "https://frontend-seven-psi-78.vercel.app";
const canonicalOauthRedirect = `${canonicalOauthOrigin}/api/v1/auth/callback`;
const testJwtSigningSecret = "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY";

class FakeStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql.replace(/\s+/g, " ").trim();
    this.values = [];
  }

  bind(...values) {
    this.values = values;
    return this;
  }

  async run() {
    if (this.sql.startsWith("INSERT INTO builds")) {
      const [id, project_id, title, prompt, prompt_sha256, model, html, gateway_mode, gateway_provider, live_provider_calls, created_at, updated_at] = this.values;
      if (this.db.builds.has(id)) throw new Error("UNIQUE constraint failed: builds.id");
      this.db.builds.set(id, { id, project_id, title, prompt, prompt_sha256, model, html, gateway_mode, gateway_provider, live_provider_calls, created_at, updated_at, deleted_at: null });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE builds SET deleted_at")) {
      const [deleted_at, updated_at, id] = this.values;
      const row = this.db.builds.get(id);
      if (!row || row.deleted_at) return { meta: { changes: 0 } };
      if (this.db.keepBuildActiveOnDelete) return { meta: { changes: 1 } };
      Object.assign(row, { deleted_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO workspace_artifacts")) {
      const [id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at] = this.values;
      this.db.artifacts.set(id, { id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at, deleted_at: null });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO native_artifacts")) {
      const [artifact_ref, project_id, probe_id, content_sha256, content_text, content_type, content_bytes, created_at] = this.values;
      if (this.db.nativeArtifacts.has(artifact_ref)) throw new Error("UNIQUE constraint failed: native_artifacts.artifact_ref");
      this.db.nativeArtifacts.set(artifact_ref, {
        artifact_ref,
        project_id,
        probe_id,
        content_sha256,
        content_text,
        content_type,
        content_bytes,
        created_at,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO hosted_sessions")) {
      const [token_sha256, session_id, provider, display_name, issued_at, expires_at] = this.values;
      if (this.db.sessions.has(token_sha256)) throw new Error("UNIQUE constraint failed: hosted_sessions.token_sha256");
      this.db.sessions.set(token_sha256, {
        token_sha256,
        session_id,
        provider,
        display_name,
        issued_at,
        expires_at,
        revoked_at: null,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE hosted_sessions SET revoked_at")) {
      const [revoked_at, token_sha256] = this.values;
      const row = this.db.sessions.get(token_sha256);
      if (!row || row.revoked_at) return { meta: { changes: 0 } };
      row.revoked_at = revoked_at;
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM native_artifacts")) {
      return { meta: { changes: this.db.nativeArtifacts.delete(this.values[0]) ? 1 : 0 } };
    }
    if (this.sql.startsWith("INSERT INTO runtime_runs")) {
      const [id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at] = this.values;
      this.db.runs.set(id, { id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO agent_tasks")) {
      const [id, run_id, agent_role, status, input_json, output_json, created_at, updated_at] = this.values;
      this.db.tasks.push({ id, run_id, agent_role, status, input_json, output_json, created_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO memory_entries")) {
      const [id, project_id, run_id, kind, content, metadata_json, created_at] = this.values;
      this.db.memory.push({ id, project_id, run_id, kind, content, metadata_json, created_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO audit_events")) {
      if (this.db.failAuditWrites) throw new Error("simulated audit persistence failure");
      const [id, event_type, trace_id, subject_id, details_json, created_at] = this.values;
      this.db.audit.push({ id, event_type, trace_id, subject_id, details_json, created_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO oauth_states")) {
      const [state, created_at, expires_at] = this.values;
      this.db.oauthStates.set(state, { state, created_at, expires_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM oauth_states")) {
      if (this.db.failOauthStateDeletes) throw new Error("simulated oauth state delete failure");
      const state = this.values[0];
      const nowIso = this.values[1];
      const row = this.db.oauthStates.get(state);
      const existed = Boolean(row && (!nowIso || row.expires_at > nowIso));
      if (existed) this.db.oauthStates.delete(state);
      return { meta: { changes: existed ? 1 : 0 } };
    }
    if (this.sql.startsWith("INSERT INTO refresh_token_families")) {
      if (this.db.failRefreshWrites) throw new Error("simulated refresh persistence failure");
      const [family_id, subject, active_token_hash, created_at, updated_at, expires_at] = this.values;
      if (this.db.refreshFamilies.has(family_id)) throw new Error("UNIQUE constraint failed: refresh_token_families.family_id");
      if (
        this.db.forceRefreshHashCollision
        || [...this.db.refreshFamilies.values()].some((family) => family.active_token_hash === active_token_hash)
      ) {
        throw new Error("UNIQUE constraint failed: refresh_token_families.active_token_hash");
      }
      if (Date.parse(expires_at) - Date.parse(created_at) !== 604800000) throw new Error("refresh family expiry invariant failed");
      this.db.refreshFamilies.set(family_id, {
        family_id,
        subject,
        active_token_hash,
        created_at,
        updated_at,
        expires_at,
        revoked_at: null,
        revocation_reason: null,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_families SET active_token_hash")) {
      if (this.db.failRefreshWrites) throw new Error("simulated refresh persistence failure");
      const [new_hash, updated_at, family_id, old_hash, expectedExpiry, nowIso] = this.values;
      const fam = this.db.refreshFamilies.get(family_id);
      if (
        fam
        && fam.active_token_hash === old_hash
        && !fam.revoked_at
        && (!this.sql.includes("expires_at = ?") || fam.expires_at === expectedExpiry)
        && (!this.sql.includes("expires_at > ?") || fam.expires_at > nowIso)
      ) {
        if (this.db.keepRefreshFamilyUnchanged) return { meta: { changes: 1 } };
        if (
          this.db.forceRefreshHashCollision
          || [...this.db.refreshFamilies.values()].some(
            (family) => family.family_id !== family_id && family.active_token_hash === new_hash,
          )
        ) {
          throw new Error("UNIQUE constraint failed: refresh_token_families.active_token_hash");
        }
        fam.active_token_hash = new_hash;
        fam.updated_at = updated_at;
        return { meta: { changes: 1 } };
      }
      return { meta: { changes: 0 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_families SET revoked_at")) {
      if (this.db.failRefreshWrites) throw new Error("simulated refresh persistence failure");
      const reasonMatch = this.sql.match(/revocation_reason\s*=\s*'([^']+)'/);
      const reason = reasonMatch ? reasonMatch[1] : "revoked";
      if (this.sql.includes("WHERE family_id = ?")) {
        const revoked_at = this.values[0];
        const hasUpdatedAt = this.sql.includes("updated_at = ?");
        const family_id = this.values[hasUpdatedAt ? 2 : 1];
        const active_token_hash = this.values[hasUpdatedAt ? 3 : 2] || null;
        const expectedExpiry = hasUpdatedAt ? this.values[4] : null;
        const nowIso = hasUpdatedAt ? this.values[5] : null;
        const fam = this.db.refreshFamilies.get(family_id);
        const expiryMatches = !hasUpdatedAt
          || (this.sql.includes("COALESCE(expires_at")
            ? String(fam?.expires_at || "") === String(expectedExpiry)
            : fam?.expires_at === expectedExpiry);
        const notExpired = !this.sql.includes("expires_at > ?") || fam?.expires_at > nowIso;
        if (fam && !fam.revoked_at && (!active_token_hash || fam.active_token_hash === active_token_hash) && expiryMatches && notExpired) {
          fam.revoked_at = revoked_at;
          if (hasUpdatedAt) fam.updated_at = this.values[1];
          fam.revocation_reason = reason;
          return { meta: { changes: 1 } };
        }
      } else if (this.sql.includes("WHERE active_token_hash = ?")) {
        const revoked_at = this.values[0];
        const active_token_hash = this.values[this.values.length - 1];
        for (const fam of this.db.refreshFamilies.values()) {
          if (fam.active_token_hash === active_token_hash) {
            fam.revoked_at = revoked_at;
            fam.revocation_reason = reason;
            return { meta: { changes: 1 } };
          }
        }
      }
      return { meta: { changes: 0 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_history SET status")) {
      if (this.db.failRefreshWrites) throw new Error("simulated refresh persistence failure");
      const [token_hash, family_id] = this.values;
      const row = this.db.refreshHistory.get(token_hash);
      if (!row || row.family_id !== family_id) return { meta: { changes: 0 } };
      row.status = "blacklisted";
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO refresh_token_history") || this.sql.startsWith("INSERT OR REPLACE INTO refresh_token_history")) {
      if (this.db.failRefreshWrites) throw new Error("simulated refresh persistence failure");
      let token_hash = this.values[0];
      let family_id = this.values[1];
      let consumed_at = this.values[2];
      if (this.sql.includes("SELECT family_id FROM refresh_token_families")) {
        family_id = this.values[1];
        const expectedActiveHash = this.values[2];
        const expectedExpiry = this.values[3];
        const hasExpiryThreshold = this.sql.includes("expires_at > ?");
        const nowIso = hasExpiryThreshold ? this.values[4] : null;
        consumed_at = this.values[hasExpiryThreshold ? 5 : 4];
        const fam = this.db.refreshFamilies.get(family_id);
        if (this.db.expireRefreshBeforeGuard && !this.db.expireRefreshBeforeGuardConsumed && hasExpiryThreshold && fam) {
          const created_at = new Date(Date.now() - 604801000).toISOString();
          const expires_at = new Date(Date.parse(created_at) + 604800000).toISOString();
          fam.created_at = created_at;
          fam.expires_at = expires_at;
          this.db.expireRefreshBeforeGuardConsumed = true;
          this.db.forcedExpiryAfterRollback = { family_id, created_at, expires_at };
        }
        const guardedFamily = this.db.refreshFamilies.get(family_id);
        const expiryMatches = this.sql.includes("COALESCE(expires_at")
          ? String(guardedFamily?.expires_at || "") === String(expectedExpiry)
          : guardedFamily?.expires_at === expectedExpiry;
        const guardPassed = guardedFamily
          && guardedFamily.active_token_hash === expectedActiveHash
          && !guardedFamily.revoked_at
          && expiryMatches
          && (!hasExpiryThreshold || guardedFamily.expires_at > nowIso);
        if (!guardPassed) throw new Error("NOT NULL constraint failed: refresh_token_history.family_id");
      }
      if (this.db.refreshHistory.has(token_hash) && !this.sql.startsWith("INSERT OR REPLACE")) {
        throw new Error("UNIQUE constraint failed: refresh_token_history.token_hash");
      }
      const literalStatus = this.sql.match(/,\s*'(rotated|revoked|blacklisted)'\s*\)$/i)?.[1];
      const suppliedStatus = this.sql.includes("SELECT family_id FROM refresh_token_families") ? null : this.values[3];
      const status = suppliedStatus || literalStatus;
      this.db.refreshHistory.set(token_hash, { token_hash, family_id, consumed_at, status });
      return { meta: { changes: 1 } };
    }
    throw new Error(`Unhandled run SQL: ${this.sql}`);
  }

  async first() {
    if (this.sql === "SELECT 1 AS ok") {
      if (this.db.failHealthRead) throw new Error("simulated health read failure");
      return { ok: 1 };
    }
    if (this.sql.startsWith("SELECT state FROM oauth_states")) {
      const [state, nowIso] = this.values;
      const row = this.db.oauthStates.get(state);
      return row && row.expires_at > nowIso ? { state: row.state } : null;
    }
    if (this.sql.startsWith("SELECT family_id, status FROM refresh_token_history")) {
      const row = this.db.refreshHistory.get(this.values[0]);
      return row ? { family_id: row.family_id, status: row.status } : null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, created_at, updated_at, expires_at, revoked_at, revocation_reason FROM refresh_token_families")) {
      if (this.db.throwRefreshReadback) throw new Error("simulated refresh readback failure");
      if (this.sql.includes("WHERE family_id = ?")) {
        const row = this.db.refreshFamilies.get(this.values[0]);
        return row ? { ...row } : null;
      }
      const activeHash = this.values[0];
      for (const fam of this.db.refreshFamilies.values()) {
        if (fam.active_token_hash === activeHash) return { ...fam };
      }
      return null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, revoked_at FROM refresh_token_families")) {
      if (this.db.throwRefreshReadback) throw new Error("simulated refresh readback failure");
      if (this.sql.includes("WHERE family_id = ?")) {
        const row = this.db.refreshFamilies.get(this.values[0]);
        return row ? {
          family_id: row.family_id,
          subject: row.subject,
          active_token_hash: row.active_token_hash,
          revoked_at: row.revoked_at,
        } : null;
      }
      const activeHash = this.values[0];
      for (const fam of this.db.refreshFamilies.values()) {
        if (fam.active_token_hash === activeHash) {
          return { family_id: fam.family_id, subject: fam.subject, active_token_hash: fam.active_token_hash, revoked_at: fam.revoked_at };
        }
      }
      return null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, revoked_at, revocation_reason FROM refresh_token_families")) {
      if (this.db.throwRefreshReadback) throw new Error("simulated refresh readback failure");
      if (this.sql.includes("WHERE family_id = ?")) {
        const row = this.db.refreshFamilies.get(this.values[0]);
        return row ? { ...row } : null;
      }
      const activeHash = this.values[0];
      for (const fam of this.db.refreshFamilies.values()) {
        if (fam.active_token_hash === activeHash) return { ...fam };
      }
      return null;
    }
    if (this.sql.startsWith("SELECT family_id FROM refresh_token_families")) {
      const activeHash = this.values[0];
      for (const fam of this.db.refreshFamilies.values()) {
        if (fam.active_token_hash === activeHash) {
          return { family_id: fam.family_id };
        }
      }
      return null;
    }
    if (this.sql.startsWith("SELECT id, event_type, trace_id, subject_id, details_json, created_at FROM audit_events")) {
      if (this.db.throwAuditReadback) throw new Error("simulated audit readback transport failure");
      if (this.db.omitAuditReadback) return null;
      const [id, eventType, traceId, subjectId] = this.values;
      const row = this.db.audit.find((item) => item.id === id &&
        item.event_type === eventType && item.trace_id === traceId && item.subject_id === subjectId);
      if (!row) return null;
      return this.db.mismatchAuditReadback ? { ...row, trace_id: `${row.trace_id}-mismatch` } : { ...row };
    }
    if (this.sql.startsWith("SELECT id, deleted_at FROM builds WHERE id")) {
      if (this.db.throwDeleteReadback) throw new Error("simulated delete readback transport failure");
      const row = this.db.builds.get(this.values[0]);
      return row && !row.deleted_at ? { id: row.id, deleted_at: row.deleted_at } : null;
    }
    if (this.sql.startsWith("SELECT * FROM builds WHERE id")) {
      if (this.db.throwBuildReadback) throw new Error("simulated build readback transport failure");
      const row = this.db.builds.get(this.values[0]);
      return row && !row.deleted_at ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM workspace_artifacts WHERE id")) {
      const row = this.db.artifacts.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.includes("FROM native_artifacts")) {
      const row = this.db.nativeArtifacts.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM runtime_runs WHERE id")) {
      const row = this.db.runs.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT session_id, provider, display_name, issued_at, expires_at FROM hosted_sessions")) {
      const [tokenSha256, now] = this.values;
      const row = this.db.sessions.get(tokenSha256);
      return row && !row.revoked_at && row.expires_at > now ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT session_id, revoked_at FROM hosted_sessions")) {
      const row = this.db.sessions.get(this.values[0]);
      return row ? { session_id: row.session_id, revoked_at: row.revoked_at } : null;
    }
    throw new Error(`Unhandled first SQL: ${this.sql}`);
  }

  async all() {
    if (this.sql.includes("FROM builds")) {
      const [projectId, limit] = this.values;
      const results = [...this.db.builds.values()]
        .filter((row) => row.project_id === projectId && !row.deleted_at)
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map(({ html: _html, deleted_at: _deletedAt, ...row }) => row);
      return { results };
    }
    if (this.sql.includes("FROM workspace_artifacts")) {
      const [projectId, limit] = this.values;
      const results = [...this.db.artifacts.values()]
        .filter((row) => row.project_id === projectId && !row.deleted_at)
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map((row) => ({ ...row }));
      return { results };
    }
    if (this.sql.includes("FROM runtime_runs")) {
      const [limit] = this.values;
      const results = [...this.db.runs.values()]
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map((row) => ({ ...row }));
      return { results };
    }
    if (this.sql.includes("FROM agent_tasks")) {
      return { results: this.db.tasks.filter((row) => row.run_id === this.values[0]).map((row) => ({ ...row })) };
    }
    if (this.sql.includes("FROM memory_entries")) {
      return { results: this.db.memory.filter((row) => row.run_id === this.values[0]).map((row) => ({ ...row })) };
    }
    throw new Error(`Unhandled all SQL: ${this.sql}`);
  }
}

class FakeD1 {
  constructor({
    failAuditWrites = false,
    omitAuditReadback = false,
    mismatchAuditReadback = false,
    throwAuditReadback = false,
    throwBuildReadback = false,
    throwDeleteReadback = false,
    keepBuildActiveOnDelete = false,
    failOauthStateDeletes = false,
    failRefreshWrites = false,
    keepRefreshFamilyUnchanged = false,
    throwRefreshReadback = false,
    expireRefreshBeforeGuard = false,
    forceRefreshHashCollision = false,
    failHealthRead = false,
  } = {}) {
    this.builds = new Map();
    this.artifacts = new Map();
    this.nativeArtifacts = new Map();
    this.sessions = new Map();
    this.oauthStates = new Map();
    this.refreshFamilies = new Map();
    this.refreshHistory = new Map();
    this.runs = new Map();
    this.tasks = [];
    this.memory = [];
    this.audit = [];
    this.failAuditWrites = failAuditWrites;
    this.omitAuditReadback = omitAuditReadback;
    this.mismatchAuditReadback = mismatchAuditReadback;
    this.throwAuditReadback = throwAuditReadback;
    this.throwBuildReadback = throwBuildReadback;
    this.throwDeleteReadback = throwDeleteReadback;
    this.keepBuildActiveOnDelete = keepBuildActiveOnDelete;
    this.failOauthStateDeletes = failOauthStateDeletes;
    this.failRefreshWrites = failRefreshWrites;
    this.keepRefreshFamilyUnchanged = keepRefreshFamilyUnchanged;
    this.throwRefreshReadback = throwRefreshReadback;
    this.expireRefreshBeforeGuard = expireRefreshBeforeGuard;
    this.forceRefreshHashCollision = forceRefreshHashCollision;
    this.failHealthRead = failHealthRead;
    this.expireRefreshBeforeGuardConsumed = false;
    this.forcedExpiryAfterRollback = null;
  }

  prepare(sql) {
    return new FakeStatement(this, sql);
  }

  async batch(statements) {
    const snapshot = {
      builds: new Map([...this.builds].map(([key, value]) => [key, { ...value }])),
      artifacts: new Map([...this.artifacts].map(([key, value]) => [key, { ...value }])),
      nativeArtifacts: new Map([...this.nativeArtifacts].map(([key, value]) => [key, { ...value }])),
      sessions: new Map([...this.sessions].map(([key, value]) => [key, { ...value }])),
      oauthStates: new Map([...this.oauthStates].map(([key, value]) => [key, { ...value }])),
      refreshFamilies: new Map([...this.refreshFamilies].map(([key, value]) => [key, { ...value }])),
      refreshHistory: new Map([...this.refreshHistory].map(([key, value]) => [key, { ...value }])),
      runs: new Map([...this.runs].map(([key, value]) => [key, { ...value }])),
      tasks: this.tasks.map((value) => ({ ...value })),
      memory: this.memory.map((value) => ({ ...value })),
      audit: this.audit.map((value) => ({ ...value })),
    };
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      return results;
    } catch (error) {
      this.builds = snapshot.builds;
      this.artifacts = snapshot.artifacts;
      this.nativeArtifacts = snapshot.nativeArtifacts;
      this.sessions = snapshot.sessions;
      this.oauthStates = snapshot.oauthStates;
      this.refreshFamilies = snapshot.refreshFamilies;
      this.refreshHistory = snapshot.refreshHistory;
      this.runs = snapshot.runs;
      this.tasks = snapshot.tasks;
      this.memory = snapshot.memory;
      this.audit = snapshot.audit;
      if (this.forcedExpiryAfterRollback) {
        const forced = this.forcedExpiryAfterRollback;
        const family = this.refreshFamilies.get(forced.family_id);
        if (family) {
          family.created_at = forced.created_at;
          family.expires_at = forced.expires_at;
        }
        this.forcedExpiryAfterRollback = null;
      }
      throw error;
    }
  }
}

class FakeDurableStorage {
  constructor(values) {
    this.values = values;
  }

  async get(key) {
    const value = this.values.get(key);
    return value === undefined ? undefined : structuredClone(value);
  }

  async put(key, value) {
    this.values.set(key, structuredClone(value));
  }

  async delete(key) {
    return this.values.delete(key);
  }
}

class FakeDurableNamespace {
  constructor() {
    this.objects = new Map();
  }

  idFromName(name) {
    return name;
  }

  get(id) {
    if (!this.objects.has(id)) {
      const values = new Map();
      const instance = new RuntimeCoordinator({ storage: new FakeDurableStorage(values) }, {});
      this.objects.set(id, { fetch: (request) => instance.fetch(request) });
    }
    return this.objects.get(id);
  }
}

class FakeQueue {
  constructor() {
    this.messages = [];
  }

  async send(body) {
    this.messages.push(structuredClone(body));
  }
}

function env(options = {}) {
  return {
    DB: new FakeD1(options),
    AGENT_API_AUTH_TOKEN: token,
    RUNTIME_MODE: options.runtimeMode || "cloudflare_native_local_candidate",
    RUNTIME_COORDINATOR: new FakeDurableNamespace(),
    RUNTIME_QUEUE: new FakeQueue(),
    GITHUB_OAUTH_CLIENT_ID: options.githubClientId !== undefined ? options.githubClientId : "Iv1.8a61f9b3a7aba766",
    GITHUB_OAUTH_CLIENT_SECRET: options.githubClientSecret !== undefined ? options.githubClientSecret : "0123456789abcdef0123456789abcdef01234567",
    OAUTH_PUBLIC_ORIGIN: options.oauthPublicOrigin !== undefined ? options.oauthPublicOrigin : canonicalOauthOrigin,
    GITHUB_OAUTH_REDIRECT_URI: options.githubRedirectUri !== undefined ? options.githubRedirectUri : canonicalOauthRedirect,
    GITHUB_OAUTH_OWNER_IDS: options.githubOwnerIds !== undefined ? options.githubOwnerIds : "123456,789012",
    JWT_SIGNING_SECRET: options.jwtSigningSecret !== undefined ? options.jwtSigningSecret : testJwtSigningSecret,
    PRODUCTION_AUTH_OWNER_GRANTED: options.productionAuthOwnerGranted !== undefined ? options.productionAuthOwnerGranted : "true",
    PRODUCTION_AUTH_OWNER_GRANT_REF: options.productionAuthOwnerGrantRef !== undefined
      ? options.productionAuthOwnerGrantRef
      : "capability-gate:production_auth_identity:test-owner-approved",
    SOURCE_BUNDLE_SHA256: options.sourceBundleSha256,
  };
}

function writeRequest(path, body, suppliedToken = token, method = "POST", requestId = null) {
  const headers = {
    "content-type": "application/json",
    "x-superbrain-agent-token": suppliedToken,
  };
  if (requestId) headers["x-request-id"] = requestId;
  return new Request(`https://state.example${path}`, {
    method,
    headers,
    body: method === "DELETE" ? undefined : JSON.stringify(body),
  });
}

function queueDelivery(body, attempts = 1) {
  return {
    body: structuredClone(body),
    attempts,
    acked: 0,
    retried: 0,
    ack() { this.acked += 1; },
    retry() { this.retried += 1; },
  };
}

function responseCookies(response) {
  return response.headers.getSetCookie
    ? response.headers.getSetCookie()
    : [response.headers.get("set-cookie")].filter(Boolean);
}

function cookieValue(response, name) {
  const match = responseCookies(response).join("\n").match(new RegExp(`${name}=([^;]+)`));
  return match?.[1] || null;
}

function seedOauthState(fakeEnv, label = crypto.randomUUID().replaceAll("-", "")) {
  const state = `phase3-auth-state-${label.slice(0, 32).padEnd(24, "0")}`;
  fakeEnv.DB.oauthStates.set(state, {
    state,
    created_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 600_000).toISOString(),
  });
  return state;
}

async function invokeGithubCallback(fakeEnv, {
  state = seedOauthState(fakeEnv),
  userId = 123456,
  scope = "read:user",
  tokenType = "bearer",
  accept = "application/json",
  postLoginRedirect,
} = {}) {
  if (postLoginRedirect !== undefined) fakeEnv.POST_LOGIN_REDIRECT = postLoginRedirect;
  const originalFetch = globalThis.fetch;
  const calls = { exchange: 0, user: 0 };
  const exchangeRedirectUris = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    if (url === "https://github.com/login/oauth/access_token") {
      calls.exchange += 1;
      exchangeRedirectUris.push(JSON.parse(String(init.body)).redirect_uri);
      return Response.json({ access_token: "unit_fixture_provider_token", scope, token_type: tokenType });
    }
    if (url === "https://api.github.com/user") {
      calls.user += 1;
      return Response.json({ id: userId, login: "unit-owner" });
    }
    throw new Error(`unexpected outbound URL: ${url}`);
  };
  try {
    const response = await worker.fetch(new Request(
      `https://state.example/api/v1/auth/callback?code=unit-code&state=${state}`,
      { headers: { accept, cookie: `__Host-sb_oauth_state=${state}` } },
    ), fakeEnv);
    return { response, calls, state, exchangeRedirectUris };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

async function signedTestJwt(payload, secret, header = { alg: "HS256", typ: "JWT" }) {
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString("base64url");
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const key = await crypto.subtle.importKey(
    "raw",
    Buffer.from(secret, "base64url"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  return `${encodedHeader}.${encodedPayload}.${Buffer.from(signature).toString("base64url")}`;
}

function decodedJwtPayload(tokenValue) {
  return JSON.parse(Buffer.from(tokenValue.split(".")[1], "base64url").toString("utf8"));
}

function setRefreshFamilyAge(family, elapsedSeconds) {
  const nowSec = Math.floor(Date.now() / 1000);
  const createdSec = nowSec - elapsedSeconds;
  family.created_at = new Date(createdSec * 1000).toISOString();
  family.updated_at = family.created_at;
  family.expires_at = new Date((createdSec + 604800) * 1000).toISOString();
}

const validBuild = {
  id: "build_test_1",
  project_id: "default",
  title: "T2 Live Proof",
  prompt: "Create a tiny proof page",
  model: "@cf/qwen/qwen2.5-coder-32b-instruct",
  html: "<!doctype html><html><body><h1>T2 Live Proof</h1></body></html>",
  gateway_mode: "cloudflare_workers_ai_live",
  gateway_provider: "cloudflare-workers-ai",
  live_provider_calls: true,
};

test("health verifies the D1 binding without a provider call", async () => {
  const bundleSha = "a".repeat(64);
  const response = await worker.fetch(new Request("https://state.example/api/v1/health"), env({ sourceBundleSha256: bundleSha }));
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.status, "healthy");
  assert.equal(body.d1_read_verified, true);
  assert.equal(body.live_provider_calls, false);
  assert.equal(body.secret_output, false);
  assert.equal(body.source_bundle_sha256, bundleSha);

  for (const invalid of [undefined, "A".repeat(64), "a".repeat(63), "g".repeat(64), ` ${bundleSha}`]) {
    const invalidResponse = await worker.fetch(
      new Request("https://state.example/api/v1/health"),
      env({ sourceBundleSha256: invalid }),
    );
    assert.equal((await invalidResponse.json()).source_bundle_sha256, null);
  }

  const failedProbe = await worker.fetch(
    new Request("https://state.example/api/v1/health"),
    env({ sourceBundleSha256: bundleSha, failHealthRead: true }),
  );
  assert.equal(failedProbe.status, 503);
  assert.equal((await failedProbe.json()).source_bundle_sha256, bundleSha);

  const blockedEnv = env({ sourceBundleSha256: bundleSha });
  delete blockedEnv.AGENT_API_AUTH_TOKEN;
  const blockedHealth = await worker.fetch(new Request("https://state.example/api/v1/health"), blockedEnv);
  assert.equal(blockedHealth.status, 503);
  assert.equal((await blockedHealth.json()).source_bundle_sha256, bundleSha);
});

test("writes require the dedicated server-side agent token", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", validBuild, "wrong-token"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 401);
  assert.equal(body.error, "stateful_runtime_authentication_required");
  assert.equal(fakeEnv.DB.builds.size, 0);
});

test("hosted opaque sessions survive create-verify-revoke with hash-only D1 storage", async () => {
  const fakeEnv = env({ runtimeMode: "cloudflare_native_hosted_candidate" });
  const created = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "name",
    name: "Hosted Tester",
  }), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 201);
  assert.equal(createdBody.status, "created");
  assert.equal(createdBody.persisted, true);
  assert.equal(createdBody.session_backend, "cloudflare-d1");
  assert.equal(createdBody.token_storage, "sha256_only");
  assert.equal(createdBody.audit_persisted, true);
  assert.match(createdBody.session_token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(createdBody.session.provider, "name");
  assert.equal(createdBody.session.name, "Hosted Tester");
  assert.equal("secret_output" in createdBody, false);
  assert.equal(fakeEnv.DB.sessions.size, 1);
  const stored = [...fakeEnv.DB.sessions.values()][0];
  assert.match(stored.token_sha256, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(stored).includes(createdBody.session_token), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(createdBody.session_token), false);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_hosted_session_created");

  const verified = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  const verifiedText = await verified.text();
  const verifiedBody = JSON.parse(verifiedText);
  assert.equal(verified.status, 200);
  assert.equal(verifiedBody.status, "verified");
  assert.equal(verifiedBody.valid, true);
  assert.equal(verifiedBody.session.id, createdBody.session.id);
  assert.equal(verifiedBody.session_token_returned, false);
  assert.equal(verifiedText.includes(createdBody.session_token), false);

  const unknown = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: "A".repeat(43),
  }), fakeEnv);
  const unknownBody = await unknown.json();
  assert.equal(unknown.status, 200);
  assert.equal(unknownBody.valid, false);
  assert.equal(unknownBody.reason, "missing_expired_or_revoked");

  const revoked = await worker.fetch(writeRequest("/api/v1/auth/sessions/revoke", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  const revokedText = await revoked.text();
  const revokedBody = JSON.parse(revokedText);
  assert.equal(revoked.status, 200);
  assert.equal(revokedBody.status, "signed_out");
  assert.equal(revokedBody.revoked, true);
  assert.equal(revokedBody.audit_persisted, true);
  assert.equal(revokedBody.session_token_returned, false);
  assert.equal(revokedText.includes(createdBody.session_token), false);
  assert.equal(fakeEnv.DB.audit[1].event_type, "cloudflare_d1_hosted_session_revoked");

  const afterRevoke = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  assert.equal((await afterRevoke.json()).valid, false);
});

test("hosted session issuance is authenticated, validated, and audit-atomic", async () => {
  const unauthorizedEnv = env();
  const unauthorized = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "guest",
  }, "wrong-token"), unauthorizedEnv);
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorizedEnv.DB.sessions.size, 0);

  const invalid = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "github",
    name: "Unsupported",
  }), unauthorizedEnv);
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error, "invalid_identity");
  assert.equal(unauthorizedEnv.DB.sessions.size, 0);

  const auditFailureEnv = env({ failAuditWrites: true });
  const auditFailure = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "guest",
  }), auditFailureEnv);
  const auditFailureBody = await auditFailure.json();
  assert.equal(auditFailure.status, 503);
  assert.equal(auditFailureBody.error, "hosted_session_persistence_failed");
  assert.equal(auditFailureEnv.DB.sessions.size, 0);
  assert.equal(auditFailureEnv.DB.audit.length, 0);
});

test("a generated build survives the create-list-read-delete registry roundtrip", async () => {
  const fakeEnv = env();
  const createRequestId = "phase6-create-request";
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild, token, "POST", createRequestId), fakeEnv);
  const createdText = await created.text();
  const createdBody = JSON.parse(createdText);
  assert.equal(created.status, 201);
  assert.equal(createdBody.persisted, true);
  assert.equal(createdBody.share_path, "/run/build_test_1");
  assert.equal(createdBody.live_provider_calls, true);
  assert.equal(createdBody.request_id, createRequestId);
  assert.match(createdBody.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(createdBody.audit_persisted, true);
  assert.equal(createdBody.audit_readback_verified, true);
  assert.equal(createdBody.direct_provider_calls, false);
  assert.equal(createdBody.secret_output, false);
  assert.equal("prompt" in createdBody, false);
  assert.equal(createdText.includes(validBuild.prompt), false);
  assert.equal(createdText.includes(token), false);
  assert.match(createdBody.prompt_sha256, /^[a-f0-9]{64}$/);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).prompt, "[REDACTED]");
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_build_created");
  assert.equal(fakeEnv.DB.audit[0].id, createdBody.audit_event_id);
  assert.equal(fakeEnv.DB.audit[0].trace_id, createRequestId);
  assert.equal(fakeEnv.DB.audit[0].subject_id, validBuild.id);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(validBuild.prompt), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(validBuild.html), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(token), false);

  const listed = await worker.fetch(new Request("https://state.example/api/v1/builds?project_id=default&limit=24"), fakeEnv);
  const listedBody = await listed.json();
  assert.equal(listed.status, 200);
  assert.equal(listedBody.count, 1);
  assert.equal(listedBody.builds[0].id, validBuild.id);
  assert.equal("html" in listedBody.builds[0], false);
  assert.equal("prompt" in listedBody.builds[0], false);

  const read = await worker.fetch(new Request(`https://state.example/api/v1/build/${validBuild.id}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.html, validBuild.html);
  assert.equal("prompt" in readBody, false);

  const deleteRequestId = "phase6-delete-request";
  const deleted = await worker.fetch(writeRequest(
    `/api/v1/build/${validBuild.id}`,
    null,
    token,
    "DELETE",
    deleteRequestId,
  ), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.request_id, deleteRequestId);
  assert.match(deletedBody.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(deletedBody.audit_persisted, true);
  assert.equal(deletedBody.audit_readback_verified, true);
  assert.equal(deletedBody.delete_readback_verified, true);
  assert.equal(fakeEnv.DB.audit[1].id, deletedBody.audit_event_id);
  assert.equal(fakeEnv.DB.audit[1].trace_id, deleteRequestId);
  assert.equal(fakeEnv.DB.audit[1].subject_id, validBuild.id);
  const afterDelete = await worker.fetch(new Request(`https://state.example/api/v1/build/${validBuild.id}`), fakeEnv);
  assert.equal(afterDelete.status, 404);
});

test("an unconfirmed build batch reports unknown outcome while the fake D1 rolls back atomically", async () => {
  const fakeEnv = env({ failAuditWrites: true });
  const response = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_persistence_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.audit_persisted, null);
  assert.equal(body.retry_safe, false);
  assert.equal(body.reconciliation_required, true);
  assert.equal(body.secret_output, false);
  assert.equal("html" in body, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("build creation reports unknown outcome when committed readback is unavailable or mismatched", async () => {
  for (const option of ["omitAuditReadback", "mismatchAuditReadback", "throwAuditReadback", "throwBuildReadback"]) {
    const fakeEnv = env({ [option]: true });
    const requestId = `create-${option}`;
    const response = await worker.fetch(writeRequest("/api/v1/builds", {
      ...validBuild,
      id: `build_${option}`,
    }, token, "POST", requestId), fakeEnv);
    const text = await response.text();
    const body = JSON.parse(text);
    assert.equal(response.status, 503);
    assert.equal(body.error, "build_persistence_outcome_unknown");
    assert.equal(body.request_id, requestId);
    assert.equal(body.id, `build_${option}`);
    assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
    assert.equal(body.accepted, null);
    assert.equal(body.persisted, null);
    assert.equal(body.mutation_outcome, "unknown");
    assert.equal(body.audit_persisted, null);
    assert.equal(body.audit_readback_verified, false);
    assert.equal(body.retry_safe, false);
    assert.equal(body.reconciliation_required, true);
    assert.equal("html" in body, false);
    assert.equal(text.includes(validBuild.prompt), false);
    assert.equal(text.includes(token), false);
    assert.equal(/not persisted/i.test(body.note), false);
    assert.equal(fakeEnv.DB.builds.has(`build_${option}`), true);
    assert.equal(fakeEnv.DB.audit.length, 1);
  }
});

test("an unconfirmed delete batch reports unknown outcome while the fake D1 rolls back atomically", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  assert.equal(created.status, 201);
  fakeEnv.DB.failAuditWrites = true;

  const response = await worker.fetch(writeRequest(`/api/v1/build/${validBuild.id}`, null, token, "DELETE"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_delete_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.deleted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.retry_safe, false);
  assert.equal(body.reconciliation_required, true);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).deleted_at, null);
  assert.equal(fakeEnv.DB.audit.length, 1);
});

test("build deletion reports unknown outcome when committed readback is unavailable or mismatched", async () => {
  for (const option of ["omitAuditReadback", "mismatchAuditReadback", "throwAuditReadback", "throwDeleteReadback"]) {
    const fakeEnv = env();
    const id = `build_delete_${option}`;
    const created = await worker.fetch(writeRequest("/api/v1/builds", { ...validBuild, id }), fakeEnv);
    assert.equal(created.status, 201);
    fakeEnv.DB[option] = true;

    const requestId = `delete-${option}`;
    const response = await worker.fetch(writeRequest(`/api/v1/build/${id}`, null, token, "DELETE", requestId), fakeEnv);
    const text = await response.text();
    const body = JSON.parse(text);
    assert.equal(response.status, 503);
    assert.equal(body.error, "build_delete_outcome_unknown");
    assert.equal(body.request_id, requestId);
    assert.equal(body.id, id);
    assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
    assert.equal(body.accepted, null);
    assert.equal(body.persisted, null);
    assert.equal(body.deleted, null);
    assert.equal(body.mutation_outcome, "unknown");
    assert.equal(body.audit_persisted, null);
    assert.equal(body.audit_readback_verified, false);
    assert.equal(body.delete_readback_verified, false);
    assert.equal(body.retry_safe, false);
    assert.equal(body.reconciliation_required, true);
    assert.equal(text.includes(token), false);
    assert.equal(/not deleted/i.test(body.note), false);
    assert.notEqual(fakeEnv.DB.builds.get(id).deleted_at, null);
    assert.equal(fakeEnv.DB.audit.length, 2);
  }
});

test("build deletion rejects a reported update that leaves the build active", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  assert.equal(created.status, 201);
  fakeEnv.DB.keepBuildActiveOnDelete = true;

  const response = await worker.fetch(writeRequest(`/api/v1/build/${validBuild.id}`, null, token, "DELETE"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_delete_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.deleted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.reconciliation_required, true);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).deleted_at, null);
  assert.equal(fakeEnv.DB.audit.at(-1).event_type, "cloudflare_d1_build_delete_requested");
});

test("not-found build deletion persists and verifies an exactly bound audit event", async () => {
  const fakeEnv = env();
  const requestId = "phase6-delete-not-found";
  const missingId = "missing_build";
  const response = await worker.fetch(writeRequest(
    `/api/v1/build/${missingId}`,
    null,
    token,
    "DELETE",
    requestId,
  ), fakeEnv);
  const text = await response.text();
  const body = JSON.parse(text);
  assert.equal(response.status, 404);
  assert.equal(body.status, "not_found");
  assert.equal(body.request_id, requestId);
  assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(body.deleted, false);
  assert.equal(body.audit_persisted, true);
  assert.equal(body.audit_readback_verified, true);
  assert.equal(body.delete_readback_verified, true);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].id, body.audit_event_id);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_build_delete_requested");
  assert.equal(fakeEnv.DB.audit[0].trace_id, requestId);
  assert.equal(fakeEnv.DB.audit[0].subject_id, missingId);
  assert.equal(text.includes(token), false);
});

test("known secret forms are rejected before build persistence and never echoed", async () => {
  const fakeEnv = env();
  const fakeSecret = ["sk", "unitfixture0000000000000000"].join("-");
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_secret_rejected",
    title: `Do not persist ${fakeSecret}`,
  }), fakeEnv);
  const text = await response.text();
  assert.equal(response.status, 400);
  assert.equal(text.includes(fakeSecret), false);
  assert.equal(JSON.parse(text).error, "secret_material_rejected");
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("known-dead three.js addon references are rejected before build persistence", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_unrunnable_rejected",
    html: '<!doctype html><html><body><script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script></body></html>',
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.error, "invalid_html_runnability");
  assert.equal(body.persisted, false);
  assert.equal(body.secret_output, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);

  const moduleWithoutMapEnv = env();
  const moduleWithoutMap = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_module_without_map_rejected",
    html: '<!doctype html><html><body><script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script></body></html>',
  }), moduleWithoutMapEnv);
  assert.equal(moduleWithoutMap.status, 400);
  assert.equal((await moduleWithoutMap.json()).error, "invalid_html_runnability");
  assert.equal(moduleWithoutMapEnv.DB.builds.size, 0);
  assert.equal(moduleWithoutMapEnv.DB.audit.length, 0);

  const moduleWithMapEnv = env();
  const moduleWithMap = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_module_with_map_allowed",
    html: '<!doctype html><html><body><script type=importmap>{"imports":{"three":"https://unpkg.com/three@0.160.0/build/three.module.js"}}</script><script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script></body></html>',
  }), moduleWithMapEnv);
  assert.equal(moduleWithMap.status, 201);
  assert.equal((await moduleWithMap.json()).persisted, true);
  assert.equal(moduleWithMapEnv.DB.builds.size, 1);
  assert.equal(moduleWithMapEnv.DB.audit.length, 1);
});

test("a THREE global without a core dependency is rejected before D1 persistence", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_missing_three_core_rejected",
    html: "<!doctype html><html><body><script>const scene=new THREE.Scene();</script></body></html>",
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.error, "invalid_html_runnability");
  assert.equal(body.persisted, false);
  assert.equal(body.secret_output, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("public build reads redact legacy titles and never expose raw prompts", async () => {
  const fakeEnv = env();
  const fakeSecret = ["ghp", "unitfixture0000000000000000"].join("_");
  fakeEnv.DB.builds.set("legacy_build", {
    ...validBuild,
    id: "legacy_build",
    title: `Legacy ${fakeSecret}`,
    prompt: `private ${fakeSecret}`,
    prompt_sha256: null,
    live_provider_calls: 0,
    created_at: new Date(0).toISOString(),
    updated_at: new Date(0).toISOString(),
    deleted_at: null,
  });
  const listed = await worker.fetch(new Request("https://state.example/api/v1/builds?project_id=default"), fakeEnv);
  const body = await listed.json();
  const serialized = JSON.stringify(body);
  assert.equal(listed.status, 200);
  assert.equal(serialized.includes(fakeSecret), false);
  assert.equal(serialized.includes("prompt\""), false);
  assert.equal(body.builds[0].title.includes("***MASKED_SECRET***"), true);
});

test("workspace artifacts use the same authenticated D1 boundary", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Persisted through D1",
    status: "created",
    metadata: { format: "md" },
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 201);
  assert.equal(body.artifact.persisted, true);
  assert.equal(body.artifact.metadata.format, "md");
  assert.equal(body.audit_persisted, true);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_workspace_artifact_created");

  const listed = await worker.fetch(new Request("https://state.example/api/v1/workspace/artifacts?project_id=default"), fakeEnv);
  const listedBody = await listed.json();
  assert.equal(listedBody.count, 1);
  assert.equal(listedBody.artifacts[0].artifact_type, "document");
});

test("workspace artifact persistence rolls back when its audit write fails", async () => {
  const fakeEnv = env({ failAuditWrites: true });
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Persisted only with audit",
    status: "created",
    metadata: { format: "md" },
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "artifact_persistence_failed");
  assert.equal(fakeEnv.DB.artifacts.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("workspace artifacts reject nested secret metadata without echoing it", async () => {
  const fakeEnv = env();
  const fakeSecret = ["github", "pat", "unitfixture0000000000000000"].join("_");
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Secret-safe fixture",
    status: "created",
    metadata: { nested: { credential: fakeSecret } },
  }), fakeEnv);
  const text = await response.text();
  assert.equal(response.status, 400);
  assert.equal(text.includes(fakeSecret), false);
  assert.equal(JSON.parse(text).error, "secret_material_rejected");
  assert.equal(fakeEnv.DB.artifacts.size, 0);
});

test("unmatched writes are never proxied to the contract origin", async () => {
  const fakeEnv = { ...env(), CONTRACT_ORIGIN: "https://contract.example" };
  const response = await worker.fetch(writeRequest("/api/v1/unmatched-write", { action: "mutate" }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 405);
  assert.equal(body.error, "contract_origin_read_only");
  assert.equal(body.accepted, false);
});

test("team status is a native read-only degraded projection on both aliases", async () => {
  const expectedRoles = ["supervisor", "planner", "explorer", "coder", "tester"];
  const expectedRoleMap = {
    supervisor: "planner",
    planner: "planner",
    explorer: "planner",
    coder: "coder",
    tester: "tester",
  };

  for (const path of ["/api/v1/team/status", "/team/status"]) {
    const response = await worker.fetch(new Request(`https://state.example${path}`, {
      headers: { "x-request-id": "team-status-unit" },
    }), env());
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("x-superbrain-source"), "cloudflare-workers-d1-stateful-runtime");
    assert.equal(body.contract_version, "autonomous-coding-team-v1");
    assert.equal(body.dispatch_contract_version, "autonomous-task-dispatch-v1");
    assert.equal(body.team_mode, "logical_five_role_overlay_on_runtime_pool");
    assert.equal(body.runtime_source, "external_adapter");
    assert.equal(body.status, "external_degraded");
    assert.equal(body.dispatch_id, null);
    assert.equal(body.request_id, "team-status-unit");
    assert.equal(body.queue_depth, 0);
    assert.deepEqual(body.queue_depth_by_priority, { high: 0, mid: 0, low: 0 });
    assert.equal(body.queue_depth_observed, false);
    assert.deepEqual(body.logical_roles, expectedRoles);
    assert.deepEqual(body.logical_to_execution_map, expectedRoleMap);
    assert.equal(body.runtime_pool_contract_version, "task-assignment-queue-contract-v1");
    assert.equal(body.external_runtime.ready, false);
    assert.equal(body.external_runtime.runtime, "cloud_native_read_only_projection");
    assert.equal(body.external_runtime.error, "internal_queue_unavailable_at_read_boundary");
    assert.deepEqual(body.external_runtime.agents, []);
    assert.deepEqual(body.external_runtime.logical_role_map, expectedRoleMap);
    assert.equal(body.members.length, expectedRoles.length);
    assert.deepEqual(body.members.map((member) => member.logical_role), expectedRoles);
    for (const member of body.members) {
      assert.equal(member.execution_agent_type, expectedRoleMap[member.logical_role]);
      assert.equal(member.status, "unavailable");
      assert.equal(member.latest_status, "unavailable");
      assert.equal(member.priority, null);
      assert.equal(member.priority_level, null);
      assert.equal(member.priority_queue, null);
      assert.equal(member.current_status_source, "external_runtime");
    }
    for (const guard of [
      "live_provider_calls",
      "direct_provider_calls",
      "live_mcp_writes",
      "provider_writes",
      "production_deploy",
      "production_rollout_claimed",
      "secret_output",
    ]) {
      assert.equal(body[guard], false, `${guard} must remain fail-closed`);
      assert.equal(body.external_runtime[guard], false, `external_runtime.${guard} must remain fail-closed`);
    }
    assert.equal(body.non_claims.some((claim) => claim.includes("does not claim live provider execution")), true);
    assert.equal(body.non_claims.includes("The read-only projection does not observe or mutate the internal task queue."), true);
  }
});

test("team status fails closed for every nonempty dispatch id without echoing it", async () => {
  const dispatchIds = [
    "123e4567-e89b-42d3-a456-426614174000",
    "token=unitfixture000000000000000000000000",
  ];

  for (const path of ["/api/v1/team/status", "/team/status"]) {
    for (const dispatchId of dispatchIds) {
      const encodedDispatchId = encodeURIComponent(dispatchId);
      const response = await worker.fetch(new Request(
        `https://state.example${path}?dispatch_id=${encodedDispatchId}`,
      ), env());
      const text = await response.text();
      const body = JSON.parse(text);

      assert.equal(response.status, 404);
      assert.equal(body.contract_version, "autonomous-coding-team-v1");
      assert.equal(body.error, "dispatch_not_found");
      assert.equal(body.dispatch_id, null);
      assert.equal(text.includes(dispatchId), false);
      assert.equal(text.includes(encodedDispatchId), false);
      assert.equal(body.live_provider_calls, false);
      assert.equal(body.live_mcp_writes, false);
      assert.equal(body.production_deploy, false);
      assert.equal(body.secret_output, false);
    }
  }
});

test("LangGraph executes four roles and persists run, tasks, checkpoint, memory, and audit", async () => {
  const fakeEnv = env();
  const contract = await worker.fetch(new Request("https://state.example/api/v1/phase2/runtime/contract"), fakeEnv);
  const contractBody = await contract.json();
  assert.equal(contractBody.engine, "langgraph-js");
  assert.deepEqual(contractBody.graph_nodes, ["planner", "coder", "tester", "devops"]);

  const started = await worker.fetch(writeRequest("/api/v1/phase2/runtime/start", {
    project_id: "default",
    prompt: "Deterministic hosted runtime proof",
  }), fakeEnv);
  const startedBody = await started.json();
  assert.equal(started.status, 201);
  assert.equal(startedBody.status, "completed");
  assert.equal(startedBody.engine, "langgraph-js");
  assert.equal(startedBody.checkpointing, "cloudflare-d1");
  assert.equal(startedBody.role_results.length, 4);
  assert.equal(startedBody.task_count, 4);
  assert.equal(startedBody.memory_persisted, true);
  assert.equal(fakeEnv.DB.runs.size, 1);
  assert.equal(fakeEnv.DB.tasks.length, 4);
  assert.equal(fakeEnv.DB.memory.length, 1);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(JSON.stringify([...fakeEnv.DB.runs.values()]).includes("Deterministic hosted runtime proof"), false);

  const read = await worker.fetch(new Request(`https://state.example/api/v1/phase2/runtime/runs/${startedBody.run_id}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.tasks.length, 4);
  assert.equal(readBody.memory_records.length, 1);
  assert.equal(readBody.secret_output, false);
});

test("Cloudflare-native candidate contract is fail-closed and labels local proof honestly", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(new Request("https://state.example/api/v1/cloud-native/contract"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.contract_version, "cloudflare-native-runtime-candidate-v2");
  assert.equal(body.status, "configured");
  assert.equal(body.engine, "langgraph-js");
  assert.equal(body.coordination, "durable-object-sqlite");
  assert.equal(body.dispatch, "cloudflare-queues");
  assert.equal(body.checkpointing, "cloudflare-d1-custom");
  assert.equal(body.official_langgraph_checkpointer, false);
  assert.equal(body.artifact_store, "cloudflare-d1-bounded-text");
  assert.equal(body.artifact_content_max_bytes, 32768);
  assert.equal(body.artifact_content_publicly_readable, false);
  assert.deepEqual(body.bindings, {
    d1: true,
    durable_object_sqlite: true,
    queue: true,
  });
  assert.deepEqual(body.historical_adapters, [{
    id: "cloudflare-r2",
    status: "historical_only",
    active: false,
    binding_configured: false,
    zero_card_verified: false,
  }]);
  assert.equal(body.dev_only, true);
  assert.equal(body.hosted_proof, false);
  assert.equal(body.live_provider_calls, false);
  assert.equal(body.direct_provider_calls, false);
  assert.equal(body.live_mcp_writes, false);
  assert.equal(body.production_deploy, false);
});

test("Cloudflare-native probe crosses D1 artifact storage, Queue, and Durable Object idempotently then cleans up", async () => {
  const fakeEnv = env();
  const requestBody = {
    project_id: "default",
    idempotency_key: "unit-native-probe",
    content: "safe local adapter proof",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);
  assert.equal(createdBody.status, "queued");
  assert.equal(createdBody.accepted, true);
  assert.equal(createdBody.dev_only, true);
  assert.equal(createdBody.hosted_proof, false);
  assert.equal(createdBody.d1_read_verified, true);
  assert.equal(createdBody.d1_artifact_persisted, true);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);
  assert.equal(JSON.stringify(fakeEnv.RUNTIME_QUEUE.messages[0]).includes(requestBody.content), false);
  assert.equal(JSON.stringify(createdBody).includes(requestBody.content), false);
  assert.equal([...fakeEnv.DB.nativeArtifacts.values()][0].content_text, requestBody.content);
  assert.ok(createdBody.queue_envelope_bytes < 64_000);

  const replayed = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const replayedBody = await replayed.json();
  assert.equal(replayed.status, 202);
  assert.equal(replayedBody.probe_id, createdBody.probe_id);
  assert.equal(replayedBody.replayed, true);
  assert.equal(replayedBody.queue_enqueued, false);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);

  const firstDelivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [firstDelivery] }, fakeEnv);
  assert.equal(firstDelivery.acked, 1);
  assert.equal(firstDelivery.retried, 0);

  const duplicateDelivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [duplicateDelivery] }, fakeEnv);
  assert.equal(duplicateDelivery.acked, 1);
  assert.equal(duplicateDelivery.retried, 0);

  const stateUrl = `/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.status, "completed");
  assert.equal(readBody.queue_delivery_count, 1);
  assert.equal(readBody.artifact_present, true);
  assert.equal(readBody.artifact_verified, true);
  assert.equal(readBody.dev_only, true);
  assert.equal(readBody.hosted_proof, false);

  const deleted = await worker.fetch(writeRequest(stateUrl, null, token, "DELETE"), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.status, "deleted");
  assert.equal(deletedBody.artifact_deleted, true);
  assert.equal(deletedBody.dev_only, true);
  assert.equal(deletedBody.hosted_proof, false);
  assert.equal(deletedBody.direct_provider_calls, false);
  assert.equal(deletedBody.live_mcp_writes, false);
  assert.equal(deletedBody.production_deploy, false);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);

  const afterDelete = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const afterDeleteBody = await afterDelete.json();
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDeleteBody.dev_only, true);
  assert.equal(afterDeleteBody.hosted_proof, false);
});

test("Cloudflare-native hosted candidate labels the full probe lifecycle without production claims", async () => {
  const fakeEnv = env({ runtimeMode: "cloudflare_native_hosted_candidate" });
  const contract = await worker.fetch(new Request("https://state.example/api/v1/cloud-native/contract"), fakeEnv);
  const contractBody = await contract.json();
  assert.equal(contract.status, 200);
  assert.equal(contractBody.dev_only, false);
  assert.equal(contractBody.hosted_proof, true);
  assert.equal(contractBody.evidence_ref, "cloudflare_native_do_queue_d1_artifact_hosted_candidate");
  assert.equal(contractBody.direct_provider_calls, false);
  assert.equal(contractBody.live_mcp_writes, false);
  assert.equal(contractBody.production_deploy, false);

  const requestBody = {
    project_id: "default",
    idempotency_key: "unit-native-hosted-probe",
    content: "safe owner-gated hosted candidate proof",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);
  assert.equal(createdBody.dev_only, false);
  assert.equal(createdBody.hosted_proof, true);
  assert.equal(createdBody.direct_provider_calls, false);
  assert.equal(createdBody.live_mcp_writes, false);
  assert.equal(createdBody.production_deploy, false);

  const delivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [delivery] }, fakeEnv);
  assert.equal(delivery.acked, 1);

  const stateUrl = `/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.status, "completed");
  assert.equal(readBody.artifact_verified, true);
  assert.equal(readBody.dev_only, false);
  assert.equal(readBody.hosted_proof, true);
  assert.equal(readBody.direct_provider_calls, false);
  assert.equal(readBody.live_mcp_writes, false);
  assert.equal(readBody.production_deploy, false);

  const deleted = await worker.fetch(writeRequest(stateUrl, null, token, "DELETE"), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.dev_only, false);
  assert.equal(deletedBody.hosted_proof, true);
  assert.equal(deletedBody.direct_provider_calls, false);
  assert.equal(deletedBody.live_mcp_writes, false);
  assert.equal(deletedBody.production_deploy, false);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);
});

test("Cloudflare-native conflicting idempotency replay preserves the original coordinator state", async () => {
  const fakeEnv = env();
  const original = {
    project_id: "default",
    idempotency_key: "unit-native-conflict",
    content: "original safe content",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", original), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);

  const conflict = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", {
    ...original,
    content: "different safe content",
  }), fakeEnv);
  assert.equal(conflict.status, 409);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);

  const stateUrl = `https://state.example/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(stateUrl), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.content_sha256, createdBody.content_sha256);
  assert.equal(readBody.status, "queued");
  assert.equal(readBody.artifact_present, true);
});

test("Cloudflare-native mutations reject missing auth and secret material before storage", async () => {
  const fakeEnv = env();
  const body = {
    project_id: "default",
    idempotency_key: "unit-native-secret",
    content: `unsafe ${["sk", "unitfixture0000000000000000"].join("-")}`,
  };
  const unauthorized = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", body, "wrong-token"), fakeEnv);
  assert.equal(unauthorized.status, 401);
  const rejected = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", body), fakeEnv);
  const rejectedText = await rejected.text();
  assert.equal(rejected.status, 400);
  assert.equal(JSON.parse(rejectedText).error, "secret_material_rejected");
  assert.equal(rejectedText.includes(body.content), false);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 0);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);
});

test("Cloudflare-native queue retry is bounded and cannot regress a failed terminal state", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", {
    project_id: "default",
    idempotency_key: "unit-native-terminal",
    content: "terminal state proof",
  }), fakeEnv);
  const createdBody = await created.json();
  const message = fakeEnv.RUNTIME_QUEUE.messages[0];
  const artifact = structuredClone(fakeEnv.DB.nativeArtifacts.get(message.artifact_ref));
  fakeEnv.DB.nativeArtifacts.delete(message.artifact_ref);

  const terminalDelivery = queueDelivery(message, 3);
  await worker.queue({ messages: [terminalDelivery] }, fakeEnv);
  assert.equal(terminalDelivery.acked, 1);
  assert.equal(terminalDelivery.retried, 0);

  const stateUrl = `https://state.example/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const failed = await worker.fetch(new Request(stateUrl), fakeEnv);
  assert.equal((await failed.json()).status, "failed");

  fakeEnv.DB.nativeArtifacts.set(message.artifact_ref, artifact);
  const lateDelivery = queueDelivery(message, 1);
  await worker.queue({ messages: [lateDelivery] }, fakeEnv);
  assert.equal(lateDelivery.acked, 0);
  assert.equal(lateDelivery.retried, 1);
  const stillFailed = await worker.fetch(new Request(stateUrl), fakeEnv);
  assert.equal((await stillFailed.json()).status, "failed");
});

test("OAuth contract reports fail-closed configuration status", async () => {
  const fakeEnv = env();
  const contract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), fakeEnv);
  const body = await contract.json();
  assert.equal(contract.status, 200);
  assert.equal(body.contract_version, "auth-github-jwt-refresh-v1");
  assert.equal(body.mode, "verified_identity_fail_closed");
  assert.equal(body.credential_issuance_ready, true);
  assert.equal(body.credentials_configured, true);
  assert.equal(body.github_oauth_client_id_configured, true);
  assert.equal(body.oauth_public_origin_configured, true);
  assert.equal(body.github_oauth_redirect_uri_canonical, true);
  assert.equal(body.jwt_signing_configured, true);
  assert.equal(body.owner_activation_granted, true);
  assert.equal(body.owner_activation_grant_ref_configured, true);
  assert.equal(body.owner_identity_allowlist_configured, true);
  assert.deepEqual(body.activation_blockers, []);
  assert.equal(body.jwt.algorithm, "HS256");
  assert.equal(body.refresh_token.storage, "hash_only_d1");

  const unconfiguredEnv = env({ githubClientSecret: "" });
  const unconfiguredContract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), unconfiguredEnv);
  const unconfiguredBody = await unconfiguredContract.json();
  assert.equal(unconfiguredContract.status, 200);
  assert.equal(unconfiguredBody.mode, "local_contract_with_dry_run_oauth");
  assert.equal(unconfiguredBody.credential_issuance_ready, false);
});

test("OAuth refresh expiry migration fixes the seven-day invariant without modifying prior migrations", () => {
  const migration = readFileSync(new URL("../migrations/0007_oauth_refresh_expiry.sql", import.meta.url), "utf8");
  assert.match(migration, /ALTER TABLE refresh_token_families\s+ADD COLUMN expires_at TEXT;/);
  assert.match(migration, /\+604800 seconds/g);
  assert.match(migration, /refresh_expiry_migration_required/);
  assert.match(
    migration,
    /CREATE UNIQUE INDEX IF NOT EXISTS idx_refresh_token_families_active_token_hash\s+ON refresh_token_families\(active_token_hash\);/,
  );
  assert.match(migration, /trg_refresh_token_families_expiry_insert/);
  assert.match(migration, /trg_refresh_token_families_expiry_update/);
  assert.match(migration, /RAISE\(ABORT, 'refresh family expiry must equal created_at \+ 604800 seconds'\)/);
});

test("OAuth origin is runtime-parameterized while preview config stays candidate-bound", () => {
  const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const config = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
  assert.equal(source.includes(canonicalOauthOrigin), false);
  assert.equal(config.vars.OAUTH_PUBLIC_ORIGIN, canonicalOauthOrigin);
  assert.equal(config.vars.GITHUB_OAUTH_REDIRECT_URI, `${config.vars.OAUTH_PUBLIC_ORIGIN}/api/v1/auth/callback`);
  assert.equal(config.env.preview.vars.RUNTIME_MODE, "cloudflare_native_hosted_candidate");
  for (const name of [
    "CONTRACT_ORIGIN",
    "OAUTH_PUBLIC_ORIGIN",
    "GITHUB_OAUTH_CLIENT_ID",
    "GITHUB_OAUTH_REDIRECT_URI",
    "GITHUB_OAUTH_OWNER_IDS",
    "POST_LOGIN_REDIRECT",
  ]) {
    assert.equal(Object.hasOwn(config.env.preview.vars, name), false, `${name} must be deploy-wrapper-bound for preview`);
  }
});

test("OAuth runtime configuration requires the canonical callback, GitHub client shape, and decoded 256-bit signing key", async () => {
  const invalidConfigurations = [
    [{ oauthPublicOrigin: null }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "http://candidate-oauth.vercel.app" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://localhost" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.workers.dev" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://vercel.app" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://*.vercel.app" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app/" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app:443" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app:8443" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app/login" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app?preview=1" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://candidate-oauth.vercel.app#fragment" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: "https://user@candidate-oauth.vercel.app" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ oauthPublicOrigin: " https://candidate-oauth.vercel.app" }, "OAUTH_PUBLIC_ORIGIN"],
    [{ githubRedirectUri: "" }, "GITHUB_OAUTH_REDIRECT_URI"],
    [{ githubRedirectUri: "http://localhost:8081/api/v1/auth/callback" }, "GITHUB_OAUTH_REDIRECT_URI"],
    [{ githubRedirectUri: "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/auth/callback" }, "GITHUB_OAUTH_REDIRECT_URI"],
    [{ githubRedirectUri: `${canonicalOauthRedirect}?next=/workbench` }, "GITHUB_OAUTH_REDIRECT_URI"],
    [{ githubRedirectUri: "https://*.vercel.app/api/v1/auth/callback" }, "GITHUB_OAUTH_REDIRECT_URI"],
    [{ githubClientId: "test-github-client-id" }, "GITHUB_OAUTH_CLIENT_ID"],
    [{ githubClientId: "Iv1.not-hexadecimal" }, "GITHUB_OAUTH_CLIENT_ID"],
    [{ jwtSigningSecret: "plain.text-signing-secret-at-least-32-bytes" }, "JWT_SIGNING_SECRET_BASE64URL_256_BIT_MINIMUM"],
    [{ jwtSigningSecret: Buffer.alloc(31, 7).toString("base64url") }, "JWT_SIGNING_SECRET_BASE64URL_256_BIT_MINIMUM"],
    [{ jwtSigningSecret: `${testJwtSigningSecret}=` }, "JWT_SIGNING_SECRET_BASE64URL_256_BIT_MINIMUM"],
  ];
  for (const [options, blocker] of invalidConfigurations) {
    const fakeEnv = env(options);
    const contract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), fakeEnv);
    const body = await contract.json();
    assert.equal(body.credential_issuance_ready, false);
    assert.ok(body.missing_configuration.includes(blocker));
    assert.equal(JSON.stringify(body).includes(fakeEnv.JWT_SIGNING_SECRET), false);
    const start = await worker.fetch(new Request("https://state.example/api/v1/auth/github"), fakeEnv);
    assert.equal(start.status, 200);
    assert.equal((await start.json()).status, "configuration_required");
    assert.equal(fakeEnv.DB.oauthStates.size, 0);
  }

  for (const clientId of ["Iv1.8a61f9b3a7aba766", "Ov23liA1B2C3D4E5F6G7"]) {
    const ready = await worker.fetch(
      new Request("https://state.example/api/v1/auth/contract"),
      env({ githubClientId: clientId }),
    );
    assert.equal((await ready.json()).credential_issuance_ready, true);
  }

  const candidateOrigin = "https://candidate-oauth-preview-abc123.vercel.app";
  const candidateEnv = env({
    oauthPublicOrigin: candidateOrigin,
    githubRedirectUri: `${candidateOrigin}/api/v1/auth/callback`,
  });
  const candidateContract = await worker.fetch(
    new Request("https://state.example/api/v1/auth/contract"),
    candidateEnv,
  );
  assert.equal((await candidateContract.json()).credential_issuance_ready, true);
  const candidateStart = await worker.fetch(new Request("https://state.example/api/v1/auth/github"), candidateEnv);
  assert.equal(new URL(candidateStart.headers.get("location")).searchParams.get("redirect_uri"), `${candidateOrigin}/api/v1/auth/callback`);
  const { response: candidateCallback, exchangeRedirectUris } = await invokeGithubCallback(candidateEnv);
  assert.equal(candidateCallback.status, 200);
  assert.deepEqual(exchangeRedirectUris, [`${candidateOrigin}/api/v1/auth/callback`]);
});

test("OAuth credentials and owner IDs cannot activate issuance without an explicit owner grant", async () => {
  for (const grant of [undefined, true, "TRUE", " true", "true "]) {
    const candidateEnv = env({ productionAuthOwnerGranted: grant });
    if (grant === undefined) delete candidateEnv.PRODUCTION_AUTH_OWNER_GRANTED;
    const candidateContract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), candidateEnv);
    const candidateBody = await candidateContract.json();
    assert.equal(candidateBody.credentials_configured, true);
    assert.equal(candidateBody.owner_identity_allowlist_configured, true);
    assert.equal(candidateBody.owner_activation_granted, false);
    assert.equal(candidateBody.credential_issuance_ready, false);
    assert.deepEqual(candidateBody.activation_blockers, ["production_auth_identity_owner_grant"]);
  }

  const fakeEnv = env({ productionAuthOwnerGranted: "TRUE" });
  const start = await worker.fetch(new Request("https://state.example/api/v1/auth/github"), fakeEnv);
  const startBody = await start.json();
  assert.equal(start.status, 200);
  assert.equal(startBody.status, "owner_activation_required");
  assert.deepEqual(startBody.activation_blockers, ["production_auth_identity_owner_grant"]);
  assert.equal(startBody.credentials_issued, false);
  assert.equal(fakeEnv.DB.oauthStates.size, 0);
});

test("OAuth owner activation still fails closed when the owner allowlist is invalid", async () => {
  for (const ownerIds of ["", "0", "123456,invalid", "123456,123456", "1".repeat(17)]) {
    const fakeEnv = env({ githubOwnerIds: ownerIds });
    const contract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), fakeEnv);
    const body = await contract.json();
    assert.equal(body.owner_identity_allowlist_configured, false);
    assert.equal(body.owner_identity_allowlist_count, 0);
    assert.equal(body.credentials_configured, false);
    assert.equal(body.credential_issuance_ready, false);
    assert.ok(body.missing_configuration.includes("GITHUB_OAUTH_OWNER_IDS"));
  }
});

test("OAuth owner activation rejects a missing or malformed bounded grant reference", async () => {
  for (const grantRef of [undefined, " owner-grant ", "x".repeat(257), "owner-grant\nref"]) {
    const fakeEnv = env({ productionAuthOwnerGranted: "true", productionAuthOwnerGrantRef: grantRef });
    if (grantRef === undefined) delete fakeEnv.PRODUCTION_AUTH_OWNER_GRANT_REF;
    const contract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), fakeEnv);
    const body = await contract.json();
    assert.equal(body.credentials_configured, true);
    assert.equal(body.owner_activation_grant_ref_configured, false);
    assert.equal(body.owner_activation_granted, false);
    assert.equal(body.credential_issuance_ready, false);
    assert.deepEqual(body.activation_blockers, ["production_auth_identity_owner_grant_ref"]);
  }
});

test("OAuth owner activation requires the exact grant signal and a bounded reference", async () => {
  const grantRef = "capability-gate:production_auth_identity:owner-approved";
  const fakeEnv = env({
    productionAuthOwnerGranted: "true",
    productionAuthOwnerGrantRef: grantRef,
  });
  const contract = await worker.fetch(new Request("https://state.example/api/v1/auth/contract"), fakeEnv);
  const body = await contract.json();
  assert.equal(body.owner_activation_granted, true);
  assert.equal(body.owner_activation_grant_ref_configured, true);
  assert.equal(body.credential_issuance_ready, true);
  assert.deepEqual(body.activation_blockers, []);
  assert.equal(JSON.stringify(body).includes(grantRef), false);
});

test("OAuth start issues state cookie and 303 redirect when configured", async () => {
  const fakeEnv = env();
  const start = await worker.fetch(new Request("https://state.example/api/v1/auth/github"), fakeEnv);
  assert.equal(start.status, 303);
  const location = start.headers.get("location");
  assert.ok(location.startsWith("https://github.com/login/oauth/authorize?"));
  assert.ok(location.includes("client_id=Iv1.8a61f9b3a7aba766"));
  assert.ok(location.includes(`redirect_uri=${encodeURIComponent(canonicalOauthRedirect)}`));
  assert.ok(location.includes("scope=read%3Auser") || location.includes("scope=read:user"));
  const setCookie = start.headers.get("set-cookie");
  assert.ok(setCookie.includes("__Host-sb_oauth_state=phase3-auth-state-"));
  assert.ok(setCookie.includes("SameSite=Lax"));
  assert.ok(setCookie.includes("HttpOnly"));
  assert.ok(setCookie.includes("Secure"));
  assert.equal(fakeEnv.DB.oauthStates.size, 1);
});

test("invalid runtime configuration fails closed across callback, me, and active refresh", async () => {
  const fakeEnv = env();
  const { response: issued } = await invokeGithubCallback(fakeEnv);
  assert.equal(issued.status, 200);
  const accessToken = cookieValue(issued, "__Host-sb_access");
  const refreshToken = cookieValue(issued, "__Host-sb_refresh");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  const originalHash = family.active_token_hash;

  fakeEnv.GITHUB_OAUTH_REDIRECT_URI = "https://state.example/api/v1/auth/callback";
  const { response: blockedCallback, calls } = await invokeGithubCallback(fakeEnv);
  assert.equal(blockedCallback.status, 503);
  assert.equal((await blockedCallback.json()).error, "github_oauth_not_configured");
  assert.deepEqual(calls, { exchange: 0, user: 0 });

  const me = await worker.fetch(new Request("https://state.example/api/v1/auth/me", {
    headers: { cookie: `__Host-sb_access=${accessToken}` },
  }), fakeEnv);
  assert.equal(me.status, 503);
  assert.equal((await me.json()).error, "auth_configuration_required");

  const refresh = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  assert.equal(refresh.status, 503);
  assert.equal((await refresh.json()).error, "auth_configuration_required");
  assert.equal(family.active_token_hash, originalHash);
  assert.equal(family.revoked_at, null);
});

test("OAuth HTML callback redirects only to the strict post-login allowlist", async () => {
  for (const [configuredRedirect, expectedRedirect] of [
    [undefined, "/workbench"],
    ["/login", "/login"],
    ["/workbench", "/workbench"],
    ["https://attacker.invalid/capture", "/workbench"],
    ["//attacker.invalid/capture", "/workbench"],
  ]) {
    const fakeEnv = env();
    const { response } = await invokeGithubCallback(fakeEnv, {
      accept: "text/html,application/xhtml+xml",
      postLoginRedirect: configuredRedirect,
    });
    assert.equal(response.status, 303);
    assert.equal(response.headers.get("location"), expectedRedirect);
    const cookies = responseCookies(response).join("\n");
    assert.match(cookies, /__Host-sb_oauth_state=""/);
    assert.match(cookies, /__Host-sb_access=/);
    assert.match(cookies, /__Host-sb_refresh=/);
    assert.equal(cookies.includes("Domain="), false);
  }
});

test("OAuth callback stores an exact fixed family expiry and correlates a non-public stable sid", async () => {
  const fakeEnv = env();
  const { response } = await invokeGithubCallback(fakeEnv);
  const responseBody = await response.json();
  const accessToken = cookieValue(response, "__Host-sb_access");
  const refreshToken = cookieValue(response, "__Host-sb_refresh");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.equal(Date.parse(family.expires_at) - Date.parse(family.created_at), 604800000);
  assert.equal(family.revoked_at, null);

  const claims = decodedJwtPayload(accessToken);
  assert.equal(claims.sid, family.family_id);
  assert.match(claims.sid, /^fam_[A-Za-z0-9_-]{22}$/);
  assert.equal(JSON.stringify(responseBody).includes(family.family_id), false);
  assert.equal(JSON.stringify(responseBody).includes(refreshToken), false);

  const callbackAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_github_callback_verified");
  const callbackDetails = JSON.parse(callbackAudit.details_json);
  assert.equal(callbackDetails.sid, family.family_id);
  assert.equal(callbackDetails.trace_id, claims.trace_id);
  assert.equal(callbackDetails.subject, claims.sub);
  assert.equal(callbackAudit.details_json.includes(refreshToken), false);
  assert.equal(callbackAudit.details_json.includes(family.active_token_hash), false);

  const me = await worker.fetch(new Request("https://state.example/api/v1/auth/me", {
    headers: { cookie: `__Host-sb_access=${accessToken}` },
  }), fakeEnv);
  const meBody = await me.json();
  assert.equal(me.status, 200);
  assert.equal(meBody.identity.subject, claims.sub);
  assert.equal(JSON.stringify(meBody).includes(family.family_id), false);
});

test("refresh family active-token hash collisions fail closed at issuance and rotation", async () => {
  const issuanceEnv = env({ forceRefreshHashCollision: true });
  const { response: rejectedIssuance } = await invokeGithubCallback(issuanceEnv);
  const issuanceBody = await rejectedIssuance.json();
  assert.equal(rejectedIssuance.status, 503);
  assert.equal(issuanceBody.error, "auth_persistence_unavailable");
  assert.equal(issuanceBody.credentials_issued, false);
  assert.equal(cookieValue(rejectedIssuance, "__Host-sb_access"), null);
  assert.equal(cookieValue(rejectedIssuance, "__Host-sb_refresh"), null);
  assert.equal(issuanceEnv.DB.refreshFamilies.size, 0);
  assert.equal(issuanceEnv.DB.audit.some((row) => row.event_type === "auth_github_callback_verified"), false);

  const rotationEnv = env();
  const { response: callback } = await invokeGithubCallback(rotationEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  const [family] = [...rotationEnv.DB.refreshFamilies.values()];
  const originalHash = family.active_token_hash;
  rotationEnv.DB.forceRefreshHashCollision = true;
  const rejectedRotation = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), rotationEnv);
  assert.equal(rejectedRotation.status, 503);
  assert.equal((await rejectedRotation.json()).error, "refresh_registry_unavailable");
  assert.equal(family.active_token_hash, originalHash);
  assert.equal(family.revoked_at, null);
  assert.equal(rotationEnv.DB.refreshHistory.size, 0);
  assert.equal(rotationEnv.DB.audit.some((row) => row.event_type === "auth_refresh_rotated"), false);
});

test("refresh rotation preserves the stable sid and never extends the fixed family expiry", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  setRefreshFamilyAge(family, 86400);
  const originalCreatedAt = family.created_at;
  const originalExpiresAt = family.expires_at;
  const sid = family.family_id;

  const refresh = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  const body = await refresh.json();
  assert.equal(refresh.status, 200);
  assert.equal(family.created_at, originalCreatedAt);
  assert.equal(family.expires_at, originalExpiresAt);
  assert.ok(body.refresh_token_expires_in <= 518400);
  assert.ok(body.refresh_token_expires_in > 518380);
  const cookieText = responseCookies(refresh).join("\n");
  assert.match(cookieText, new RegExp(`__Host-sb_refresh=[^;]+; Path=/; Max-Age=${body.refresh_token_expires_in};`));
  const rotatedClaims = decodedJwtPayload(cookieValue(refresh, "__Host-sb_access"));
  assert.equal(rotatedClaims.sid, sid);
  assert.equal(JSON.stringify(body).includes(sid), false);
  const audit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_refresh_rotated");
  assert.equal(JSON.parse(audit.details_json).sid, sid);
});

test("a copied refresh cookie is revoked with audited readback after its server-side family expiry", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const copiedRefreshToken = cookieValue(callback, "__Host-sb_refresh");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  setRefreshFamilyAge(family, 604801);
  const sid = family.family_id;

  const makeRefresh = () => worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${copiedRefreshToken}` },
  }), fakeEnv);
  const expired = await makeRefresh();
  assert.equal(expired.status, 401);
  assert.equal((await expired.json()).reason, "expired");
  assert.equal(family.revocation_reason, "refresh_token_expired");
  assert.ok(family.revoked_at);
  assert.equal(fakeEnv.DB.refreshHistory.size, 1);
  assert.equal([...fakeEnv.DB.refreshHistory.values()][0].status, "revoked");
  const expiredCookies = responseCookies(expired).join("\n");
  assert.match(expiredCookies, /__Host-sb_access=""/);
  assert.match(expiredCookies, /__Host-sb_refresh=""/);
  const expiryAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_refresh_expired");
  assert.equal(JSON.parse(expiryAudit.details_json).sid, sid);

  const copiedReplay = await makeRefresh();
  assert.equal(copiedReplay.status, 401);
  assert.equal((await copiedReplay.json()).reason, "expired");
  const rejectionAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_refresh_rejected"
    && JSON.parse(row.details_json).reason === "expired");
  assert.equal(JSON.parse(rejectionAudit.details_json).sid, sid);
});

test("expiry at the atomic rotation guard rolls back rotation and persists only expiry revocation", async () => {
  const fakeEnv = env({ expireRefreshBeforeGuard: true });
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  const refresh = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  assert.equal(refresh.status, 401);
  assert.equal((await refresh.json()).reason, "expired");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.equal(family.revocation_reason, "refresh_token_expired");
  assert.equal([...fakeEnv.DB.refreshHistory.values()].filter((row) => row.status === "rotated").length, 0);
  assert.equal(fakeEnv.DB.audit.filter((row) => row.event_type === "auth_refresh_rotated").length, 0);
  assert.equal(fakeEnv.DB.audit.filter((row) => row.event_type === "auth_refresh_expired").length, 1);
});

test("owner-disallowed refresh revocation persists guarded history and correlated audit before rejecting", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  fakeEnv.GITHUB_OAUTH_OWNER_IDS = "654321";

  const refresh = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  const body = await refresh.json();
  assert.equal(refresh.status, 403);
  assert.equal(body.error, "github_owner_identity_not_allowed");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.equal(family.revocation_reason, "owner_disallowed");
  assert.ok(family.revoked_at);
  assert.equal(fakeEnv.DB.refreshHistory.get(family.active_token_hash)?.status, "revoked");
  const audit = fakeEnv.DB.audit.find((row) => {
    if (row.event_type !== "auth_refresh_rejected") return false;
    return JSON.parse(row.details_json).reason === "github_owner_identity_not_allowed";
  });
  assert.equal(JSON.parse(audit.details_json).sid, family.family_id);
  assert.equal(JSON.stringify(body).includes(family.family_id), false);
});

test("expiry at the owner-disallow CAS wins over owner revocation and remains audit-atomic", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  fakeEnv.GITHUB_OAUTH_OWNER_IDS = "654321";
  fakeEnv.DB.expireRefreshBeforeGuard = true;

  const refresh = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  assert.equal(refresh.status, 401);
  assert.equal((await refresh.json()).reason, "expired");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.equal(family.revocation_reason, "refresh_token_expired");
  assert.equal([...fakeEnv.DB.refreshHistory.values()].filter((row) => row.status === "revoked").length, 1);
  assert.equal(fakeEnv.DB.audit.filter((row) => row.event_type === "auth_refresh_expired").length, 1);
  assert.equal(fakeEnv.DB.audit.filter((row) => {
    if (row.event_type !== "auth_refresh_rejected") return false;
    return JSON.parse(row.details_json).reason === "github_owner_identity_not_allowed";
  }).length, 0);
});

test("logout atomically expires an elapsed family and audits the same stable sid", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  setRefreshFamilyAge(family, 604801);
  const logout = await worker.fetch(new Request("https://state.example/api/v1/auth/logout", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  const body = await logout.json();
  assert.equal(logout.status, 200);
  assert.equal(body.refresh_token_revoked, true);
  assert.equal(body.active_refresh_token_absent, true);
  assert.equal(family.revocation_reason, "refresh_token_expired");
  const audit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_logout_expired");
  assert.equal(JSON.parse(audit.details_json).sid, family.family_id);
  assert.equal(JSON.stringify(body).includes(family.family_id), false);
});

test("OAuth cancel validates and consumes state exactly once without a provider call", async () => {
  const fakeEnv = env();
  const state = seedOauthState(fakeEnv, "cancel-state-fixture-000000000000");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  globalThis.fetch = async () => {
    providerCalls += 1;
    throw new Error("provider must not be called for cancel");
  };
  try {
    const makeRequest = () => new Request(
      `https://state.example/api/v1/auth/callback?error=access_denied&state=${state}`,
      { headers: { cookie: `__Host-sb_oauth_state=${state}` } },
    );
    const cancelled = await worker.fetch(makeRequest(), fakeEnv);
    assert.equal(cancelled.status, 401);
    assert.equal((await cancelled.json()).error, "oauth_provider_denied");
    assert.equal(fakeEnv.DB.oauthStates.has(state), false);
    const replay = await worker.fetch(makeRequest(), fakeEnv);
    assert.equal(replay.status, 401);
    assert.equal((await replay.json()).error, "oauth_state_invalid");
    assert.equal(providerCalls, 0);
    assert.equal(fakeEnv.DB.audit.filter((row) => row.event_type === "auth_github_callback_blocked").length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("concurrent OAuth callbacks consume one state and perform exactly one provider exchange", async () => {
  const fakeEnv = env();
  const state = seedOauthState(fakeEnv, "concurrent-state-fixture-00000000");
  const originalFetch = globalThis.fetch;
  const calls = { exchange: 0, user: 0 };
  globalThis.fetch = async (input) => {
    const url = typeof input === "string" ? input : input.url;
    if (url === "https://github.com/login/oauth/access_token") {
      calls.exchange += 1;
      return Response.json({ access_token: "unit_fixture_provider_token", scope: "read:user", token_type: "bearer" });
    }
    if (url === "https://api.github.com/user") {
      calls.user += 1;
      return Response.json({ id: 123456, login: "unit-owner" });
    }
    throw new Error(`unexpected outbound URL: ${url}`);
  };
  try {
    const makeRequest = () => new Request(
      `https://state.example/api/v1/auth/callback?code=unit-code&state=${state}`,
      { headers: { cookie: `__Host-sb_oauth_state=${state}` } },
    );
    const responses = await Promise.all([
      worker.fetch(makeRequest(), fakeEnv),
      worker.fetch(makeRequest(), fakeEnv),
    ]);
    assert.deepEqual(responses.map((response) => response.status).sort(), [200, 401]);
    assert.equal(calls.exchange, 1);
    assert.equal(calls.user, 1);
    assert.equal(fakeEnv.DB.refreshFamilies.size, 1);
    assert.equal(fakeEnv.DB.oauthStates.has(state), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("OAuth callback rejects any token scope other than exact read:user", async () => {
  const fakeEnv = env();
  const { response, calls, state } = await invokeGithubCallback(fakeEnv, { scope: "read:user repo" });
  const body = await response.json();
  assert.equal(response.status, 401);
  assert.equal(body.error, "oauth_scope_invalid");
  assert.equal(body.required_scope, "read:user");
  assert.equal(calls.exchange, 1);
  assert.equal(calls.user, 0);
  assert.equal(fakeEnv.DB.oauthStates.has(state), false);
  assert.equal(fakeEnv.DB.refreshFamilies.size, 0);
});

test("auth/me verifies exact JWT header, mandatory claims, canonical GitHub subject, and owner", async () => {
  const fakeEnv = env();
  const now = Math.floor(Date.now() / 1000);
  const baseClaims = {
    sub: "github:123456",
    sid: "fam_AAAAAAAAAAAAAAAAAAAAAA",
    provider: "github",
    provider_user_id: 123456,
    iss: "cloud-superbrain-agent-api",
    aud: "cloud-superbrain-frontend",
    iat: now,
    exp: now + 900,
    trace_id: "jwt-claims-test",
    issued_at: new Date(now * 1000).toISOString(),
    expires_at: new Date((now + 900) * 1000).toISOString(),
  };
  const invalidCases = [
    [{ ...baseClaims }, { alg: "none", typ: "JWT" }],
    [{ ...baseClaims, exp: undefined }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, iss: "wrong-issuer" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, aud: "wrong-audience" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, provider: "gitlab" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, provider_user_id: "123456" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, sub: "github:654321" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, sid: undefined }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, sid: "family-invalid" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, trace_id: "trace id" }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, issued_at: new Date((now - 1) * 1000).toISOString() }, { alg: "HS256", typ: "JWT" }],
    [{ ...baseClaims, exp: now + 1800 }, { alg: "HS256", typ: "JWT" }],
  ];
  for (const [claims, header] of invalidCases) {
    const normalizedClaims = Object.fromEntries(Object.entries(claims).filter(([, value]) => value !== undefined));
    const jwt = await signedTestJwt(normalizedClaims, fakeEnv.JWT_SIGNING_SECRET, header);
    const response = await worker.fetch(new Request("https://state.example/api/v1/auth/me", {
      headers: { cookie: `__Host-sb_access=${jwt}` },
    }), fakeEnv);
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error, "access_token_invalid");
  }

  const nonOwnerJwt = await signedTestJwt({
    ...baseClaims,
    sub: "github:999999",
    provider_user_id: 999999,
  }, fakeEnv.JWT_SIGNING_SECRET);
  const nonOwner = await worker.fetch(new Request("https://state.example/api/v1/auth/me", {
    headers: { cookie: `__Host-sb_access=${nonOwnerJwt}` },
  }), fakeEnv);
  assert.equal(nonOwner.status, 403);
  assert.equal((await nonOwner.json()).error, "github_owner_identity_not_allowed");
});

test("concurrent refresh rotation issues exactly one credential set and revokes the family on replay", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  assert.ok(refreshToken);
  const makeRequest = () => new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  });
  const responses = await Promise.all([
    worker.fetch(makeRequest(), fakeEnv),
    worker.fetch(makeRequest(), fakeEnv),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [200, 401]);
  const success = responses.find((response) => response.status === 200);
  const rejected = responses.find((response) => response.status === 401);
  const successBody = await success.json();
  assert.deepEqual(Object.keys(successBody).sort(), [
    "access_token_expires_in",
    "access_token_issued",
    "active_registry_verified",
    "audit_persisted",
    "contract_version",
    "cookie_flags",
    "old_refresh_token_blacklisted",
    "refresh_token_expires_in",
    "refresh_token_rotated",
    "status",
    "trace_id",
  ]);
  assert.equal((await rejected.json()).reason, "blacklisted");
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.ok(family.revoked_at);
  assert.equal(family.revocation_reason, "token_replay_detected");
  assert.equal(fakeEnv.DB.refreshHistory.values().next().value.status, "blacklisted");
  const rotatedAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_refresh_rotated");
  const replayAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_refresh_reuse_blocked");
  assert.equal(JSON.parse(rotatedAudit.details_json).sid, family.family_id);
  assert.equal(JSON.parse(replayAudit.details_json).sid, family.family_id);
});

test("logout atomically revokes one active refresh token, returns the RealLogin shape, and post-logout refresh is 401", async () => {
  const fakeEnv = env();
  const { response: callback } = await invokeGithubCallback(fakeEnv);
  const refreshToken = cookieValue(callback, "__Host-sb_refresh");
  const bodyOnlyLogout = await worker.fetch(new Request("https://state.example/api/v1/auth/logout", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }),
  }), fakeEnv);
  const bodyOnlyLogoutBody = await bodyOnlyLogout.json();
  assert.equal(bodyOnlyLogout.status, 200);
  assert.equal(bodyOnlyLogoutBody.body_token_accepted, false);
  assert.equal(bodyOnlyLogoutBody.refresh_token_revoked, false);
  assert.equal([...fakeEnv.DB.refreshFamilies.values()][0].revoked_at, null);
  const logout = await worker.fetch(new Request("https://state.example/api/v1/auth/logout", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  const logoutBody = await logout.json();
  assert.equal(logout.status, 200);
  assert.deepEqual(Object.keys(logoutBody).sort(), [
    "active_refresh_token_absent",
    "audit_persisted",
    "body_token_accepted",
    "contract_version",
    "cookies_cleared",
    "refresh_token_revoked",
    "status",
    "trace_id",
  ]);
  assert.equal(logoutBody.status, "logged_out");
  assert.equal(logoutBody.refresh_token_revoked, true);
  assert.equal(logoutBody.body_token_accepted, false);
  assert.equal(logoutBody.cookies_cleared, true);
  assert.equal(logoutBody.active_refresh_token_absent, true);
  assert.equal(logoutBody.audit_persisted, true);
  const [logoutFamily] = [...fakeEnv.DB.refreshFamilies.values()];
  const logoutAudit = fakeEnv.DB.audit.find((row) => row.event_type === "auth_logout_revoked");
  assert.equal(JSON.parse(logoutAudit.details_json).sid, logoutFamily.family_id);
  const clearedCookies = responseCookies(logout).join("\n");
  assert.match(clearedCookies, /__Host-sb_access=""/);
  assert.match(clearedCookies, /__Host-sb_refresh=""/);
  const [family] = [...fakeEnv.DB.refreshFamilies.values()];
  assert.equal(family.revocation_reason, "user_logout");
  assert.equal(fakeEnv.DB.refreshHistory.values().next().value.status, "revoked");

  const afterLogout = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), fakeEnv);
  assert.equal(afterLogout.status, 401);
  assert.equal((await afterLogout.json()).reason, "revoked");
});

test("callback, refresh, and logout fail closed on audit or storage failures without issuing cookies", async () => {
  const callbackAuditEnv = env({ failAuditWrites: true });
  const { response: callbackAuditFailure } = await invokeGithubCallback(callbackAuditEnv);
  assert.equal(callbackAuditFailure.status, 503);
  assert.equal(cookieValue(callbackAuditFailure, "__Host-sb_access"), null);
  assert.equal(cookieValue(callbackAuditFailure, "__Host-sb_refresh"), null);
  assert.equal(callbackAuditEnv.DB.refreshFamilies.size, 0);

  const refreshEnv = env();
  const { response: refreshCallback } = await invokeGithubCallback(refreshEnv);
  const refreshToken = cookieValue(refreshCallback, "__Host-sb_refresh");
  refreshEnv.DB.failAuditWrites = true;
  const refreshFailure = await worker.fetch(new Request("https://state.example/api/v1/auth/refresh", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
  }), refreshEnv);
  assert.equal(refreshFailure.status, 503);
  assert.equal(cookieValue(refreshFailure, "__Host-sb_access"), '""');
  assert.equal(cookieValue(refreshFailure, "__Host-sb_refresh"), '""');
  assert.equal(refreshEnv.DB.refreshHistory.size, 0);

  const logoutEnv = env();
  const { response: logoutCallback } = await invokeGithubCallback(logoutEnv);
  const logoutToken = cookieValue(logoutCallback, "__Host-sb_refresh");
  logoutEnv.DB.failAuditWrites = true;
  const logoutFailure = await worker.fetch(new Request("https://state.example/api/v1/auth/logout", {
    method: "POST",
    headers: { cookie: `__Host-sb_refresh=${logoutToken}` },
  }), logoutEnv);
  const logoutFailureBody = await logoutFailure.json();
  assert.equal(logoutFailure.status, 503);
  assert.equal(logoutFailureBody.cookies_cleared, true);
  assert.equal(logoutFailureBody.audit_persisted, false);
  assert.equal(logoutFailureBody.refresh_token_revoked, false);
  assert.equal([...logoutEnv.DB.refreshFamilies.values()][0].revoked_at, null);
});

test("OAuth callback validates state, exchanges token, enforces owner allowlist, and issues cookies", async () => {
  const fakeEnv = env();
  const originalFetch = globalThis.fetch;

  // 1. Invalid state returns 401
  const invalidStateReq = new Request("https://state.example/api/v1/auth/callback?code=test-code&state=phase3-auth-state-invalid1234567890", {
    headers: { cookie: "__Host-sb_oauth_state=phase3-auth-state-mismatch123456789" },
  });
  const invalidStateRes = await worker.fetch(invalidStateReq, fakeEnv);
  assert.equal(invalidStateRes.status, 401);
  const invalidStateBody = await invalidStateRes.json();
  assert.equal(invalidStateBody.error, "oauth_state_invalid");
  assert.ok(invalidStateRes.headers.get("set-cookie").includes('__Host-sb_oauth_state=""'));

  // 2. Mock GitHub API for token exchange and user fetch
  let mockGitHubUserId = 123456;
  globalThis.fetch = async (input, init) => {
    const urlStr = typeof input === "string" ? input : input.url;
    if (urlStr === "https://github.com/login/oauth/access_token") {
      return new Response(JSON.stringify({ access_token: "gho_mock_access_token_12345", scope: "read:user", token_type: "bearer" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (urlStr === "https://api.github.com/user") {
      return new Response(JSON.stringify({ id: mockGitHubUserId, login: "testowner" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    return originalFetch(input, init);
  };

  try {
    // Generate valid state in D1
    const validState = "phase3-auth-state-valid1234567890123456";
    fakeEnv.DB.oauthStates.set(validState, {
      state: validState,
      created_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 600000).toISOString(),
    });

    const successReq = new Request(`https://state.example/api/v1/auth/callback?code=gh_code_123&state=${validState}`, {
      headers: { cookie: `__Host-sb_oauth_state=${validState}` },
    });
    const successRes = await worker.fetch(successReq, fakeEnv);
    assert.equal(successRes.status, 200);
    const successBody = await successRes.json();
    assert.equal(successBody.status, "authenticated");
    assert.equal(successBody.identity_verified, true);
    assert.equal(successBody.access_token_issued, true);
    assert.equal(successBody.refresh_token_issued, true);
    assert.equal(successBody.audit_persisted, true);

    // State consumed from D1
    assert.equal(fakeEnv.DB.oauthStates.has(validState), false);
    // Refresh family stored in D1
    assert.equal(fakeEnv.DB.refreshFamilies.size, 1);
    // Audit event saved in D1
    assert.ok(fakeEnv.DB.audit.some((a) => a.event_type === "auth_github_callback_verified"));

    // Verify Set-Cookie headers
    const setCookies = successRes.headers.getSetCookie ? successRes.headers.getSetCookie() : [successRes.headers.get("set-cookie")];
    const cookieHeaderString = setCookies.join("\n");
    assert.ok(cookieHeaderString.includes("__Host-sb_access="));
    assert.ok(cookieHeaderString.includes("__Host-sb_refresh="));
    assert.ok(cookieHeaderString.includes('__Host-sb_oauth_state=""'));

    // Extract access and refresh tokens for subsequent tests
    const accessMatch = cookieHeaderString.match(/__Host-sb_access=([^;]+)/);
    const refreshMatch = cookieHeaderString.match(/__Host-sb_refresh=([^;]+)/);
    const accessToken = accessMatch[1];
    const refreshToken = refreshMatch[1];

    // 3. Test /api/v1/auth/me with issued access token
    const meReq = new Request("https://state.example/api/v1/auth/me", {
      headers: { cookie: `__Host-sb_access=${accessToken}` },
    });
    const meRes = await worker.fetch(meReq, fakeEnv);
    assert.equal(meRes.status, 200);
    const meBody = await meRes.json();
    assert.equal(meBody.status, "authenticated");
    assert.equal(meBody.identity.provider, "github");
    assert.equal(meBody.identity.provider_user_id, 123456);
    assert.equal(meBody.identity.subject, "github:123456");
    assert.equal(meBody.jwt_signature_verified, true);

    // 4. Test /api/v1/auth/refresh with issued refresh token
    const refreshReq = new Request("https://state.example/api/v1/auth/refresh", {
      method: "POST",
      headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
    });
    const refreshRes = await worker.fetch(refreshReq, fakeEnv);
    assert.equal(refreshRes.status, 200);
    const refreshBody = await refreshRes.json();
    assert.equal(refreshBody.status, "rotated");
    assert.equal(refreshBody.audit_persisted, true);

    const newCookies = refreshRes.headers.getSetCookie ? refreshRes.headers.getSetCookie() : [refreshRes.headers.get("set-cookie")];
    const newCookieHeaderString = newCookies.join("\n");
    const newRefreshMatch = newCookieHeaderString.match(/__Host-sb_refresh=([^;]+)/);
    const newRefreshToken = newRefreshMatch[1];

    // 5. Test Replay Attack: Reusing old refresh token must fail with 401, revoke family, and blacklist
    const replayReq = new Request("https://state.example/api/v1/auth/refresh", {
      method: "POST",
      headers: { cookie: `__Host-sb_refresh=${refreshToken}` },
    });
    const replayRes = await worker.fetch(replayReq, fakeEnv);
    assert.equal(replayRes.status, 401);
    const replayBody = await replayRes.json();
    assert.equal(replayBody.reason, "blacklisted");
    assert.ok(fakeEnv.DB.audit.some((a) => a.event_type === "auth_refresh_reuse_blocked"));

    // Family is revoked in D1
    const [family] = [...fakeEnv.DB.refreshFamilies.values()];
    assert.ok(family.revoked_at);
    assert.equal(family.revocation_reason, "token_replay_detected");

    // 6. Test /api/v1/auth/logout
    const logoutReq = new Request("https://state.example/api/v1/auth/logout", {
      method: "POST",
      headers: { cookie: `__Host-sb_refresh=${newRefreshToken}` },
    });
    const logoutRes = await worker.fetch(logoutReq, fakeEnv);
    assert.equal(logoutRes.status, 200);
    const logoutBody = await logoutRes.json();
    assert.equal(logoutBody.status, "logged_out");
    assert.ok(fakeEnv.DB.audit.some((a) => a.event_type === "auth_logout_no_active_token"));

    // 7. Disallowed owner ID returns 403
    mockGitHubUserId = 999999;
    const disallowedState = "phase3-auth-state-disallowed1234567890123456";
    fakeEnv.DB.oauthStates.set(disallowedState, {
      state: disallowedState,
      created_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 600000).toISOString(),
    });
    const disallowedReq = new Request(`https://state.example/api/v1/auth/callback?code=gh_code_999&state=${disallowedState}`, {
      headers: { cookie: `__Host-sb_oauth_state=${disallowedState}` },
    });
    const disallowedRes = await worker.fetch(disallowedReq, fakeEnv);
    assert.equal(disallowedRes.status, 403);
    const disallowedBody = await disallowedRes.json();
    assert.equal(disallowedBody.error, "github_owner_identity_not_allowed");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
