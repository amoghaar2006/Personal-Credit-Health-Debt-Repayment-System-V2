import React, { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import {
  BrowserRouter,
  NavLink,
  Route,
  Routes,
  useLocation
} from 'react-router-dom'
import {
  Activity, CircleDollarSign, CreditCard, FileText, Gauge,
  LayoutDashboard, Menu, Moon, Plus, Search, ShieldCheck,
  Sun, Trash2, Wallet, X, Pencil, RefreshCw, BrainCircuit
} from 'lucide-react'
import {
  Bar, BarChart, CartesianGrid, ResponsiveContainer,
  Tooltip, XAxis, YAxis
} from 'recharts'
import './styles.css'

const API = import.meta.env.VITE_API_URL || 'http://127.0.0.1:5000/api'

const modules = [
  {
    path: 'users',
    label: 'Users',
    icon: ShieldCheck,
    resource: 'users',
    fields: [
      { name: 'user_id', label: 'User ID', required: true }
    ]
  },
  {
    path: 'financial-profiles',
    label: 'Financial profiles',
    icon: Wallet,
    resource: 'financial-profiles',
    fields: [
      { name: 'user_id', label: 'User ID', required: true },
      { name: 'monthly_income_usd', label: 'Monthly income (USD)', type: 'number', required: true },
      { name: 'monthly_expenses_usd', label: 'Monthly expenses (USD)', type: 'number', required: true },
      { name: 'savings_usd', label: 'Savings (USD)', type: 'number', required: true },
      { name: 'has_loan', label: 'Has loan', type: 'select', options: ['Yes', 'No'], required: true },
      { name: 'debt_to_income_ratio', label: 'Debt-to-income ratio', type: 'number', required: true },
      { name: 'credit_score', label: 'Credit score', type: 'number', required: true },
      { name: 'record_date', label: 'Record date', type: 'date', required: true }
    ]
  },
  {
    path: 'loans',
    label: 'Loans',
    icon: CreditCard,
    resource: 'loans',
    fields: [
      { name: 'loan_id', label: 'Loan ID', required: true },
      { name: 'user_id', label: 'User ID', required: true },
      { name: 'loan_type', label: 'Loan type', required: true },
      { name: 'loan_amount_usd', label: 'Loan amount (USD)', type: 'number', required: true },
      { name: 'loan_term_months', label: 'Term (months)', type: 'number', required: true },
      { name: 'monthly_emi_usd', label: 'Monthly EMI (USD)', type: 'number', required: true },
      { name: 'loan_interest_rate_pct', label: 'Interest rate (%)', type: 'number', required: true }
    ]
  },
  {
    path: 'repayments',
    label: 'Repayments',
    icon: CircleDollarSign,
    resource: 'repayments',
    fields: [
      { name: 'payment_id', label: 'Payment ID', required: true },
      { name: 'loan_id', label: 'Loan ID', required: true },
      { name: 'installment_number', label: 'Installment #', type: 'number', required: true },
      { name: 'due_date', label: 'Due date', type: 'date', required: true },
      { name: 'payment_date', label: 'Payment date', type: 'date' },
      { name: 'amount_due_usd', label: 'Amount due (USD)', type: 'number', required: true },
      { name: 'amount_paid_usd', label: 'Amount paid (USD)', type: 'number' },
      { name: 'payment_status', label: 'Status', required: true },
      { name: 'remaining_balance_usd', label: 'Remaining balance (USD)', type: 'number', required: true }
    ]
  },
  {
    path: 'repayment-plans',
    label: 'Repayment plans',
    icon: FileText,
    resource: 'repayment-plans',
    fields: [
      { name: 'user_id', label: 'User ID', required: true },
      { name: 'plan_date', label: 'Plan date', type: 'date', required: true },
      { name: 'total_months', label: 'Duration (months)', type: 'number', required: true },
      { name: 'monthly_available_amount', label: 'Monthly available (USD)', type: 'number', required: true },
      { name: 'risk_level', label: 'Risk level', required: true },
      { name: 'plan_status', label: 'Plan status' }
    ]
  },
  {
    path: 'plan-payments',
    label: 'Plan payments',
    icon: Activity,
    resource: 'plan-payments',
    fields: [
      { name: 'plan_id', label: 'Plan ID', type: 'number', required: true },
      { name: 'loan_id', label: 'Loan ID', required: true },
      { name: 'due_month', label: 'Due month', type: 'date', required: true },
      { name: 'planned_amount_usd', label: 'Planned amount (USD)', type: 'number', required: true },
      { name: 'priority_order', label: 'Priority order', type: 'number', required: true }
    ]
  }
]

const money = v =>
  new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
  }).format(Number(v || 0))

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options
  })

  const data = await res.json().catch(() => ({
    error: 'Unexpected server response'
  }))

  if (!res.ok) {
    throw new Error(data.error || data.detail || `Request failed (${res.status})`)
  }

  return data
}

function AppShell({ children, theme, setTheme }) {
  // Get the current route from React Router.
  const { pathname } = useLocation()

  // Remove trailing slashes so route matching stays consistent.
  const currentPath = pathname.replace(/\/+$/, '') || '/'

  // Find the module corresponding to the current route.
  const currentModule = modules.find(
    m => `/${m.path}` === currentPath
  )

  const [collapsed, setCollapsed] = useState(false)
  const [mobile, setMobile] = useState(false)

  return (
    <div className={`app ${theme}`}>
      <aside className={`sidebar ${collapsed ? 'collapsed' : ''} ${mobile ? 'mobile-open' : ''}`}>
        <div className="brand">
          <div className="brand-mark">
            <Gauge size={20} />
          </div>

          {!collapsed && (
            <div>
              <b>Credit<span>Health</span></b>
              <small>PERSONAL FINANCE</small>
            </div>
          )}

          <button
            className="icon-btn mobile-close"
            onClick={() => setMobile(false)}
          >
            <X />
          </button>
        </div>

        <div className="nav-caption">
          {!collapsed && 'WORKSPACE'}
        </div>

        <NavLink
          end
          to="/"
          className={({ isActive }) =>
            `nav-link ${isActive ? 'active' : ''}`
          }
          onClick={() => setMobile(false)}
        >
          <LayoutDashboard size={18} />
          {!collapsed && 'Overview'}
        </NavLink>

        <div className="nav-caption">
          {!collapsed && 'MANAGE RECORDS'}
        </div>

        {modules.map(m => (
          <NavLink
            key={m.path}
            to={`/${m.path}`}
            className={({ isActive }) =>
              `nav-link ${isActive ? 'active' : ''}`
            }
            onClick={() => setMobile(false)}
          >
            <m.icon size={18} />
            {!collapsed && m.label}
          </NavLink>
        ))}
        <NavLink
          to="/financial-insights"
          className={({ isActive }) =>
            `nav-link ${isActive ? 'active' : ''}`
          }
          onClick={() => setMobile(false)}
        >
          <BrainCircuit size={18} />
          {!collapsed && 'Financial Insights'}
        </NavLink>

        <div className="sidebar-bottom">
          <div className="security-note">
            <ShieldCheck size={17} />

            {!collapsed && (
              <span>
                <b>Private workspace</b>
                <small>Connected to your MySQL database</small>
              </span>
            )}
          </div>

          <button
            className="nav-link"
            onClick={() => setCollapsed(!collapsed)}
          >
            <Menu size={18} />
            {!collapsed && 'Collapse sidebar'}
          </button>
        </div>
      </aside>

      {mobile && (
        <div
          className="scrim"
          onClick={() => setMobile(false)}
        />
      )}

      <main className="main-area">
        <header className="topbar">
          <button
            className="icon-btn menu-mobile"
            onClick={() => setMobile(true)}
          >
            <Menu />
          </button>

          {/* Dynamic breadcrumb */}
          <div className="crumb">
            Workspace <span>/</span>
            <b>
              {currentPath === '/'
                ? 'Overview'
                : currentModule?.label || 'Workspace'}
            </b>
          </div>

          <div className="top-actions">
            <div className="connection">
              <i /> MySQL connection
            </div>

            <button
              className="icon-btn"
              title="Toggle theme"
              onClick={() =>
                setTheme(theme === 'dark' ? 'light' : 'dark')
              }
            >
              {theme === 'dark'
                ? <Sun size={18} />
                : <Moon size={18} />}
            </button>

            <button className="avatar">AV</button>
          </div>
        </header>

        <div className="content">
          {children}
        </div>

        <footer>
          Personal Credit Health & Debt Repayment Planning
          <span>•</span> Database workspace
        </footer>
      </main>
    </div>
  )
}

function Dashboard() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)

  const [formData, setFormData] = useState({
    user_id: '',
    insight_type: 'debt_health',
    credit_health_score: 75,
    debt_to_income_ratio: 0.30,
    risk_level: 'Low',
    recommendations: 'Pay EMIs on time\nMaintain emergency savings'
  })

  const load = () => {
    setError('')

    api('/dashboard')
      .then(setData)
      .catch(e => setError(e.message))
  }

  useEffect(() => {
    load()
  }, [])

  const m = data?.metrics || {}

  const stats = [
    ['Total users', m.users, 'Registered profiles', ShieldCheck],
    ['Active loan records', m.loans, `${money(m.loan_total)} total principal`, CreditCard],
    ['Outstanding balance', money(m.outstanding), 'Across repayment records', Wallet],
    ['Pending repayments', m.pending_repayments, `${m.repayments || 0} repayment records`, Activity]
  ]

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="eyebrow">YOUR FINANCIAL OVERVIEW</div>
          <h1>Good to see you.</h1>
          <p>
            Here’s what’s happening across your credit and repayment records.
          </p>
        </div>

        <button className="btn secondary" onClick={load}>
          <RefreshCw size={16} /> Refresh data
        </button>
      </div>

      {error && (
        <div className="alert error">
          {error}. Check that MySQL and the Flask backend are running.
        </div>
      )}

      <div className="stat-grid">
        {stats.map(([label, value, sub, Icon]) => (
          <div className="stat-card" key={label}>
            <div className="stat-top">
              <span>{label}</span>
              <div className="stat-icon">
                <Icon size={18} />
              </div>
            </div>

            <strong>{data ? value : '—'}</strong>
            <small>{sub}</small>
          </div>
        ))}
      </div>

      <div className="dashboard-grid">
        <section className="panel chart-panel">
          <div className="panel-heading">
            <div>
              <h2>Loan portfolio</h2>
              <p>Loan principal grouped by loan type</p>
            </div>

            <span className="tag">LIVE DATA</span>
          </div>

          {data?.loan_distribution?.length ? (
            <ResponsiveContainer width="100%" height={260}>
              <BarChart
                data={data.loan_distribution}
                margin={{ top: 10, right: 10, left: 0, bottom: 0 }}
              >
                <CartesianGrid
                  strokeDasharray="3 3"
                  vertical={false}
                  stroke="var(--border)"
                />

                <XAxis
                  dataKey="loan_type"
                  tick={{ fill: 'var(--muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                />

                <YAxis
                  tick={{ fill: 'var(--muted)', fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                />

                <Tooltip formatter={v => money(v)} />

                <Bar
                  dataKey="total_amount"
                  fill="#6366F1"
                  radius={[6, 6, 0, 0]}
                />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="empty-chart">
              <CircleDollarSign size={28} />
              <b>No loan data yet</b>
              <span>Add a loan record to populate this chart.</span>
            </div>
          )}
        </section>

        <section className="panel">
          <div className="panel-heading">
            <div>
              <h2>Repayment snapshot</h2>
              <p>Current database totals</p>
            </div>
          </div>

          <div className="snapshot">
            <div>
              <span>Repayment plans</span>
              <b>{data ? m.plans : '—'}</b>
            </div>

            <div>
              <span>Total repayments</span>
              <b>{data ? m.repayments : '—'}</b>
            </div>

            <div>
              <span>Loan principal</span>
              <b>{data ? money(m.loan_total) : '—'}</b>
            </div>

            <div>
              <span>Pending items</span>
              <b className="warning-text">
                {data ? m.pending_repayments : '—'}
              </b>
            </div>
          </div>

          <div className="note">
            <ShieldCheck size={17} />
            <span>
              Figures are queried from your MySQL database.
              No dashboard values are hardcoded.
            </span>
          </div>
        </section>
      </div>

      <section className="panel recent-panel">
        <div className="panel-heading">
          <div>
            <h2>Recent repayment records</h2>
            <p>Latest due dates from your repayment table</p>
          </div>

          <NavLink to="/repayments" className="text-link">
            View all →
          </NavLink>
        </div>

        {data?.recent_repayments?.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Payment ID</th>
                  <th>Loan ID</th>
                  <th>Installment</th>
                  <th>Due date</th>
                  <th>Amount due</th>
                  <th>Status</th>
                </tr>
              </thead>

              <tbody>
                {data.recent_repayments.map(r => (
                  <tr key={r.payment_id}>
                    <td className="mono">{r.payment_id}</td>
                    <td>{r.loan_id}</td>
                    <td>{r.installment_number}</td>
                    <td>{String(r.due_date).slice(0, 10)}</td>
                    <td>{money(r.amount_due_usd)}</td>
                    <td>
                      <Status value={r.payment_status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="empty-state">
            No repayment records are available in the database yet.
          </div>
        )}
      </section>
    </>
  )
}

function Status({ value }) {
  const s = String(value || 'Unknown').toLowerCase()

  return (
    <span
      className={`status ${
        s.includes('paid') || s === 'active'
          ? 'good'
          : s.includes('late') || s.includes('overdue')
            ? 'bad'
            : 'pending'
      }`}
    >
      {value || 'Unknown'}
    </span>
  )
}

function ModulePage({ slug }) {
  const mod = modules.find(m => m.path === slug)

  const [items, setItems] = useState([])
  const [page, setPage] = useState(1)
  const [pages, setPages] = useState(1)
  const [search, setSearch] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [modal, setModal] = useState(null)
  const [toast, setToast] = useState('')

  const load = () => {
    if (!mod) return

    setBusy(true)
    setError('')

    api(
      `/${mod.resource}?page=${page}&per_page=10&search=${encodeURIComponent(search)}`
    )
      .then(d => {
        setItems(d.items)
        setPages(Math.max(1, d.pages))
      })
      .catch(e => setError(e.message))
      .finally(() => setBusy(false))
  }

  useEffect(() => {
    setPage(1)
  }, [slug, search])

  useEffect(() => {
    load()
  }, [slug, page, search])

  const primaryKeys = {
    users: 'user_id',
    'financial-profiles': 'profile_id',
    loans: 'loan_id',
    repayments: 'payment_id',
    'repayment-plans': 'plan_id',
    'plan-payments': 'plan_payment_id'
  }

  const pk = primaryKeys[slug]

  const submit = async values => {
    try {
      if (modal?.row) {
        await api(
          `/${mod.resource}/${encodeURIComponent(modal.row[pk])}`,
          {
            method: 'PUT',
            body: JSON.stringify(values)
          }
        )
      } else {
        await api(`/${mod.resource}`, {
          method: 'POST',
          body: JSON.stringify(values)
        })
      }

      setModal(null)
      setToast('Record saved successfully')
      load()
    } catch (e) {
      throw e
    }
  }

  const remove = async row => {
    if (!confirm(`Delete ${row[pk]}? This cannot be undone.`)) {
      return
    }

    try {
      await api(
        `/${mod.resource}/${encodeURIComponent(row[pk])}`,
        {
          method: 'DELETE'
        }
      )

      setToast('Record deleted')
      load()
    } catch (e) {
      setError(e.message)
    }
  }

  if (!mod) {
    return <div className="alert error">Unknown module.</div>
  }

  const cols = mod.fields.map(f => f.name)

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="eyebrow">RECORD MANAGEMENT</div>
          <h1>{mod.label}</h1>
          <p>
            Search, review and manage {mod.label.toLowerCase()}
            {' '}stored in your MySQL database.
          </p>
        </div>

        <button
          className="btn primary"
          onClick={() => setModal({ row: null })}
        >
          <Plus size={17} /> Add record
        </button>
      </div>

      {error && (
        <div className="alert error">{error}</div>
      )}

      {toast && (
        <div className="alert success">
          {toast}
          <button onClick={() => setToast('')}>
            <X size={14} />
          </button>
        </div>
      )}

      <section className="panel records-panel">
        <div className="toolbar">
          <div className="search-box">
            <Search size={17} />

            <input
              placeholder={`Search ${mod.label.toLowerCase()}...`}
              value={search}
              onChange={e => setSearch(e.target.value)}
            />

            {search && (
              <button onClick={() => setSearch('')}>
                <X size={14} />
              </button>
            )}
          </div>

          <span className="record-count">
            {busy ? 'Loading…' : `${items.length} shown`}
          </span>
        </div>

        {busy ? (
          <div className="empty-state">
            Loading records…
          </div>
        ) : items.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  {cols.map(c => (
                    <th key={c}>{c.replaceAll('_', ' ')}</th>
                  ))}
                  <th>Actions</th>
                </tr>
              </thead>

              <tbody>
                {items.map((row, i) => (
                  <tr key={row[pk] ?? i}>
                    {cols.map(c => (
                      <td key={c}>
                        {c.includes('amount') ||
                         c.includes('income') ||
                         c.includes('expenses') ||
                         c.includes('savings') ||
                         c.includes('emi')
                          ? money(row[c])
                          : c.includes('date') || c === 'due_month'
                            ? String(row[c] ?? '—').slice(0, 10)
                            : c === 'payment_status' || c === 'plan_status'
                              ? <Status value={row[c]} />
                              : String(row[c] ?? '—')}
                      </td>
                    ))}

                    <td>
                      <div className="row-actions">
                        <button
                          title="Edit"
                          onClick={() => setModal({ row })}
                        >
                          <Pencil size={15} />
                        </button>

                        <button
                          title="Delete"
                          className="danger-icon"
                          onClick={() => remove(row)}
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="empty-state">
            <FileText size={26} />
            <b>No records found</b>
            <span>
              Try a different search or add your first record.
            </span>
          </div>
        )}

        <div className="pagination">
          <span>Page {page} of {pages}</span>

          <div>
            <button
              className="btn secondary small"
              disabled={page <= 1}
              onClick={() => setPage(p => p - 1)}
            >
              Previous
            </button>

            <button
              className="btn secondary small"
              disabled={page >= pages}
              onClick={() => setPage(p => p + 1)}
            >
              Next
            </button>
          </div>
        </div>
      </section>

      {modal && (
        <RecordModal
          mod={mod}
          row={modal.row}
          onClose={() => setModal(null)}
          onSave={submit}
        />
      )}
    </>
  )
}

function RecordModal({ mod, row, onClose, onSave }) {
  const [values, setValues] = useState(() =>
    Object.fromEntries(
      mod.fields.map(f => [
        f.name,
        row?.[f.name] ?? ''
      ])
    )
  )

  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const submit = async e => {
    e.preventDefault()
    setSaving(true)
    setError('')

    const clean = { ...values }

    for (const f of mod.fields) {
      if (clean[f.name] === '') {
        delete clean[f.name]
      } else if (f.type === 'number') {
        clean[f.name] = Number(clean[f.name])
      }
    }

    try {
      await onSave(clean)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div
      className="modal-backdrop"
      onMouseDown={e =>
        e.target === e.currentTarget && onClose()
      }
    >
      <form className="modal" onSubmit={submit}>
        <div className="modal-head">
          <div>
            <h2>{row ? 'Edit record' : 'Add record'}</h2>
            <p>{mod.label}</p>
          </div>

          <button
            type="button"
            className="icon-btn"
            onClick={onClose}
          >
            <X />
          </button>
        </div>

        {error && (
          <div className="alert error">{error}</div>
        )}
        <div className="form-grid">
          {mod.fields.map(f => (
            <label key={f.name}>
              {f.label}

              {f.type === 'select' ? (
                <select
                  required={f.required}
                  value={values[f.name]}
                  onChange={e =>
                    setValues(v => ({
                      ...v,
                      [f.name]: e.target.value
                    }))
                  }
                >
                  <option value="">Select…</option>

                  {f.options.map(o => (
                    <option key={o}>{o}</option>
                  ))}
                </select>
              ) : (
                <input
                  required={f.required}
                  type={f.type || 'text'}
                  step={f.type === 'number' ? 'any' : undefined}
                  value={values[f.name]}
                  disabled={
                    !!row &&
                    f.name === ({
                      users: 'user_id',
                      loans: 'loan_id',
                      repayments: 'payment_id'
                    }[mod.path])
                  }
                  onChange={e =>
                    setValues(v => ({
                      ...v,
                      [f.name]: e.target.value
                    }))
                  }
                />
              )}
            </label>
          ))}
        </div>

        <div className="modal-actions">
          <button
            type="button"
            className="btn secondary"
            onClick={onClose}
          >
            Cancel
          </button>

          <button
            className="btn primary"
            disabled={saving}
          >
            {saving ? 'Saving…' : 'Save record'}
          </button>
        </div>
      </form>
    </div>
  )
}
function FinancialInsights() {
  const emptyForm = {
    user_id: '',
    insight_type: 'debt_health',
    credit_health_score: 75,
    debt_to_income_ratio: 0.30,
    risk_level: 'Low',
    recommendations: 'Pay EMIs on time\nMaintain emergency savings'
  }

  const [insights, setInsights] = useState([])
  const [userId, setUserId] = useState('TEST0001')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [formData, setFormData] = useState(emptyForm)

  const loadInsightsForUser = async (id = userId) => {
    setLoading(true)
    setError('')

    try {
      const cleanId = (id || '').trim()
      const query = cleanId
        ? `?user_id=${encodeURIComponent(cleanId)}`
        : ''
      const data = await api(`/financial-insights${query}`)
      setInsights(data.insights || [])
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const loadInsights = () => loadInsightsForUser(userId)

  useEffect(() => {
    loadInsightsForUser('TEST0001')
  }, [])

  const openCreateForm = () => {
    setEditingId(null)
    setFormData({ ...emptyForm })
    setError('')
    setMessage('')
    setShowForm(true)
  }

  const openEditForm = insight => {
    setEditingId(insight._id)
    setFormData({
      user_id: insight.user_id || '',
      insight_type: insight.insight_type || 'debt_health',
      credit_health_score: insight.credit_health_score ?? 75,
      debt_to_income_ratio: insight.debt_to_income_ratio ?? 0,
      risk_level: insight.risk_level || 'Low',
      recommendations: Array.isArray(insight.recommendations)
        ? insight.recommendations.join('\n')
        : ''
    })
    setError('')
    setMessage('')
    setShowForm(true)
  }

  const handleSaveInsight = async e => {
    e.preventDefault()
    setError('')
    setMessage('')

    const payload = {
      ...formData,
      user_id: formData.user_id.trim(),
      credit_health_score: Number(formData.credit_health_score),
      debt_to_income_ratio: Number(formData.debt_to_income_ratio),
      recommendations: formData.recommendations
        .split('\n')
        .map(item => item.trim())
        .filter(Boolean)
    }

    if (!payload.user_id) {
      setError('Please enter a User ID')
      return
    }
    if (
      !Number.isFinite(payload.credit_health_score) ||
      payload.credit_health_score < 0 ||
      payload.credit_health_score > 100
    ) {
      setError('Credit health score must be between 0 and 100')
      return
    }
    if (
      !Number.isFinite(payload.debt_to_income_ratio) ||
      payload.debt_to_income_ratio < 0
    ) {
      setError('Debt-to-income ratio cannot be negative')
      return
    }
    if (payload.recommendations.length === 0) {
      setError('Please enter at least one recommendation')
      return
    }

    setLoading(true)
    try {
      if (editingId) {
        await api(`/mongodb/financial-insights/${encodeURIComponent(editingId)}`, {
          method: 'PUT',
          body: JSON.stringify({
            credit_health_score: payload.credit_health_score,
            debt_to_income_ratio: payload.debt_to_income_ratio,
            risk_level: payload.risk_level,
            recommendations: payload.recommendations
          })
        })
        setMessage('Financial insight updated successfully')
      } else {
        await api('/financial-insights', {
          method: 'POST',
          body: JSON.stringify(payload)
        })
        setMessage('Financial insight created successfully')
      }

      setUserId(payload.user_id)
      setShowForm(false)
      setEditingId(null)
      setFormData({ ...emptyForm })
      await loadInsightsForUser(payload.user_id)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteInsight = async insight => {
    const confirmed = window.confirm(
      `Delete the financial insight for ${insight.user_id}? This cannot be undone.`
    )
    if (!confirmed) return

    setError('')
    setMessage('')
    setLoading(true)

    try {
      await api(`/mongodb/financial-insights/${encodeURIComponent(insight._id)}`, {
        method: 'DELETE'
      })
      setMessage('Financial insight deleted successfully')
      await loadInsightsForUser(userId)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="eyebrow">MONGODB INTEGRATION</div>
          <h1>Financial Insights</h1>
          <p>View and manage personalized financial health insights.</p>
        </div>

        <div className="row-actions">
          <button
            type="button"
            className="btn primary"
            onClick={openCreateForm}
            disabled={loading}
          >
            <Plus size={17} />
            Add Insight
          </button>

          <button
            type="button"
            className="btn secondary"
            onClick={loadInsights}
            disabled={loading}
          >
            <RefreshCw size={16} />
            Refresh
          </button>
        </div>
      </div>

      {message && (
        <div className="alert success">
          {message}
          <button type="button" onClick={() => setMessage('')}>
            <X size={14} />
          </button>
        </div>
      )}

      {error && <div className="alert error">{error}</div>}

      {showForm && (
        <form
          className="panel"
          onSubmit={handleSaveInsight}
          style={{ marginBottom: '20px' }}
        >
          <div className="panel-heading">
            <div>
              <h2>{editingId ? 'Edit Financial Insight' : 'Create Financial Insight'}</h2>
              <p>
                {editingId
                  ? 'Update the selected financial health insight.'
                  : "Enter the user's financial health information."}
              </p>
            </div>
          </div>

          <div className="form-grid">
            <label>
              User ID
              <input
                type="text"
                required
                value={formData.user_id}
                disabled={Boolean(editingId)}
                onChange={e => setFormData(v => ({ ...v, user_id: e.target.value }))}
              />
            </label>

            <label>
              Insight Type
              <select
                value={formData.insight_type}
                disabled={Boolean(editingId)}
                onChange={e => setFormData(v => ({ ...v, insight_type: e.target.value }))}
              >
                <option value="debt_health">Debt Health</option>
                <option value="credit_health">Credit Health</option>
                <option value="repayment">Repayment</option>
              </select>
            </label>

            <label>
              Credit Health Score (0–100)
              <input
                type="number"
                min="0"
                max="100"
                required
                value={formData.credit_health_score}
                onChange={e => setFormData(v => ({ ...v, credit_health_score: e.target.value }))}
              />
            </label>

            <label>
              Debt-to-Income Ratio
              <input
                type="number"
                min="0"
                step="0.01"
                required
                value={formData.debt_to_income_ratio}
                onChange={e => setFormData(v => ({ ...v, debt_to_income_ratio: e.target.value }))}
              />
            </label>

            <label>
              Risk Level
              <select
                value={formData.risk_level}
                onChange={e => setFormData(v => ({ ...v, risk_level: e.target.value }))}
              >
                <option value="Low">Low</option>
                <option value="Medium">Medium</option>
                <option value="High">High</option>
              </select>
            </label>

            <label style={{ gridColumn: '1 / -1' }}>
              Recommendations (one per line)
              <textarea
                rows="4"
                required
                value={formData.recommendations}
                onChange={e => setFormData(v => ({ ...v, recommendations: e.target.value }))}
              />
            </label>
          </div>

          <div className="modal-actions">
            <button
              type="button"
              className="btn secondary"
              onClick={() => {
                setShowForm(false)
                setEditingId(null)
                setError('')
              }}
              disabled={loading}
            >
              Cancel
            </button>
            <button type="submit" className="btn primary" disabled={loading}>
              {loading ? 'Saving…' : editingId ? 'Update Insight' : 'Save Insight'}
            </button>
          </div>
        </form>
      )}

      <section className="panel">
        <div className="toolbar">
          <div className="search-box">
            <Search size={17} />
            <input
              placeholder="Enter User ID..."
              value={userId}
              onChange={e => setUserId(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && loadInsights()}
            />
          </div>

          <button
            type="button"
            className="btn primary"
            onClick={loadInsights}
            disabled={loading}
          >
            Search
          </button>
        </div>

        {loading ? (
          <div className="empty-state">Loading financial insights...</div>
        ) : insights.length > 0 ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>User ID</th>
                  <th>Credit health score</th>
                  <th>Debt-to-income ratio</th>
                  <th>Risk level</th>
                  <th>Insight type</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {insights.map(insight => (
                  <tr key={insight._id}>
                    <td>{insight.user_id}</td>
                    <td>{insight.credit_health_score}/100</td>
                    <td>{(Number(insight.debt_to_income_ratio) * 100).toFixed(1)}%</td>
                    <td><Status value={insight.risk_level} /></td>
                    <td>{insight.insight_type}</td>
                    <td>
                      <div className="row-actions">
                        <button
                          type="button"
                          title="Edit insight"
                          aria-label="Edit insight"
                          onClick={() => openEditForm(insight)}
                          disabled={loading}
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          type="button"
                          title="Delete insight"
                          aria-label="Delete insight"
                          className="danger-icon"
                          onClick={() => handleDeleteInsight(insight)}
                          disabled={loading}
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="empty-state">
            <BrainCircuit size={28} />
            <b>No financial insights found</b>
            <span>Try another User ID or create a new insight.</span>
          </div>
        )}
      </section>
    </>
  )
}

function App() {
  const [theme, setTheme] = useState(
    localStorage.getItem('credit-theme') || 'dark'
  )

  useEffect(() => {
    localStorage.setItem('credit-theme', theme)
  }, [theme])

  return (
    <AppShell theme={theme} setTheme={setTheme}>
      <Routes>
        <Route
          path="/"
          element={<Dashboard />}
        />

        {modules.map(m => (
          <Route
            key={m.path}
            path={`/${m.path}`}
            element={<ModulePage slug={m.path} />}
          />
        ))}
        <Route
          path="/financial-insights"
          element={<FinancialInsights />}
        />

        <Route
          path="*"
          element={<Dashboard />}
        />
      </Routes>
    </AppShell>
  )
}

createRoot(document.getElementById('root')).render(
  <BrowserRouter>
    <App />
  </BrowserRouter>
)