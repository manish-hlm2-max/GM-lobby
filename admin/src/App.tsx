import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Users, 
  Wallet, 
  Trophy, 
  Play, 
  DollarSign, 
  AlertCircle, 
  Plus, 
  Check, 
  X, 
  RefreshCw 
} from 'lucide-react';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000/api';

export default function App() {
  const [token, setToken] = useState<string | null>(localStorage.getItem('admin_token'));
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [activeTab, setActiveTab] = useState<'users' | 'withdrawals' | 'tournaments' | 'matches'>('users');
  
  // Data state
  const [users, setUsers] = useState<any[]>([]);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [tournaments, setTournaments] = useState<any[]>([]);
  const [matches, setMatches] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Forms state
  const [overrideUser, setOverrideUser] = useState('');
  const [overrideAmount, setOverrideAmount] = useState(0);
  const [overrideReason, setOverrideReason] = useState('');
  
  const [tournName, setTournName] = useState('');
  const [tournEntry, setTournEntry] = useState(0);
  const [tournPrize, setTournPrize] = useState(0);
  const [tournTime, setTournTime] = useState('');

  useEffect(() => {
    if (token) {
      fetchDashboardData();
    }
  }, [token, activeTab]);

  const fetchDashboardData = async () => {
    setLoading(true);
    setError(null);
    try {
      const headers = { Authorization: `Bearer ${token}` };

      if (activeTab === 'users') {
        const res = await axios.get(`${API_BASE}/wallet/admin/users`, { headers });
        setUsers(res.data.users);
      } else if (activeTab === 'withdrawals') {
        const res = await axios.get(`${API_BASE}/wallet/admin/transactions`, { headers });
        // Filter withdrawals
        setTransactions(res.data.transactions.filter((tx: any) => tx.type === 'WITHDRAWAL'));
      } else if (activeTab === 'tournaments') {
        const res = await axios.get(`${API_BASE}/tournament`, { headers });
        setTournaments(res.data.tournaments);
      } else if (activeTab === 'matches') {
        const res = await axios.get(`${API_BASE}/match/open`, { headers });
        setMatches(res.data.matches);
      }
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to fetch data.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      const res = await axios.post(`${API_BASE}/auth/login`, {
        emailOrUsername: email,
        password
      });

      if (res.data.user.role !== 'SUPER_ADMIN' && res.data.user.role !== 'MODERATOR') {
        setError('Forbidden. Only administrators can access this portal.');
        return;
      }

      localStorage.setItem('admin_token', res.data.token);
      setToken(res.data.token);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Login failed.');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    setToken(null);
  };

  const handleWithdrawalAction = async (transactionId: string, action: 'approve' | 'reject') => {
    try {
      const headers = { Authorization: `Bearer ${token}` };
      await axios.post(`${API_BASE}/wallet/admin/withdrawal/${action}`, { transactionId }, { headers });
      fetchDashboardData();
    } catch (err: any) {
      alert(err.response?.data?.error || 'Action failed.');
    }
  };

  const handleBlockToggle = async (userId: string, block: boolean) => {
    try {
      const headers = { Authorization: `Bearer ${token}` };
      const res = await axios.post(`${API_BASE}/wallet/admin/user/block`, { targetUserId: userId, block }, { headers });
      fetchDashboardData();
      alert(res.data.message);
    } catch (err: any) {
      alert(err.response?.data?.error || 'Action failed.');
    }
  };

  const handleOverride = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const headers = { Authorization: `Bearer ${token}` };
      await axios.post(`${API_BASE}/wallet/admin/override`, {
        targetUserId: overrideUser,
        amount: overrideAmount,
        reason: overrideReason
      }, { headers });
      
      setOverrideUser('');
      setOverrideAmount(0);
      setOverrideReason('');
      fetchDashboardData();
      alert('Override successfully processed!');
    } catch (err: any) {
      alert(err.response?.data?.error || 'Override failed.');
    }
  };

  const handleCreateTournament = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const headers = { Authorization: `Bearer ${token}` };
      await axios.post(`${API_BASE}/tournament/admin/create`, {
        name: tournName,
        entryFee: tournEntry,
        totalPrize: tournPrize,
        scheduledStartTime: tournTime
      }, { headers });

      setTournName('');
      setTournEntry(0);
      setTournPrize(0);
      setTournTime('');
      fetchDashboardData();
      alert('Tournament scheduled successfully!');
    } catch (err: any) {
      alert(err.response?.data?.error || 'Failed to create tournament.');
    }
  };

  const handleStartTournament = async (tournamentId: string) => {
    try {
      const headers = { Authorization: `Bearer ${token}` };
      await axios.post(`${API_BASE}/tournament/admin/start`, { tournamentId }, { headers });
      fetchDashboardData();
      alert('Tournament matches generated successfully!');
    } catch (err: any) {
      alert(err.response?.data?.error || 'Failed to start tournament.');
    }
  };

  if (!token) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', backgroundColor: '#030712' }}>
        <div style={{ width: '400px', padding: '32px', backgroundColor: '#0f172a', border: '1px solid #1e293b', borderRadius: '20px' }}>
          <h2 style={{ textAlign: 'center', color: '#fff', fontSize: '1.5rem', marginBottom: '8px' }}>Grandmaster</h2>
          <p style={{ textAlign: 'center', color: '#64748b', fontSize: '0.9rem', marginBottom: '24px' }}>Super-Admin Portal login</p>
          {error && <div style={{ color: '#ef4444', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '12px', borderRadius: '10px', marginBottom: '16px', fontSize: '0.85rem' }}>{error}</div>}
          <form onSubmit={handleLogin}>
            <input type="text" placeholder="Admin Email / Username" value={email} onChange={(e) => setEmail(e.target.value)} required />
            <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} required />
            <button className="btn-primary" type="submit" style={{ width: '100%', marginTop: '12px' }}>Access Dashboard</button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard-container">
      {/* Sidebar */}
      <div className="sidebar">
        <div className="sidebar-title">GRANDMASTER ADMIN</div>
        <div className="nav-link-list" style={{ flex: 1 }}>
          <div className={`nav-link ${activeTab === 'users' ? 'active' : ''}`} onClick={() => setActiveTab('users')}>
            <Users className="nav-icon" /> Users Management
          </div>
          <div className={`nav-link ${activeTab === 'withdrawals' ? 'active' : ''}`} onClick={() => setActiveTab('withdrawals')}>
            <Wallet className="nav-icon" /> Withdrawals ({transactions.filter(t => t.status === 'PENDING').length})
          </div>
          <div className={`nav-link ${activeTab === 'tournaments' ? 'active' : ''}`} onClick={() => setActiveTab('tournaments')}>
            <Trophy className="nav-icon" /> Tournaments
          </div>
          <div className={`nav-link ${activeTab === 'matches' ? 'active' : ''}`} onClick={() => setActiveTab('matches')}>
            <Play className="nav-icon" /> Active Matches
          </div>
        </div>
        <button onClick={handleLogout} style={{ backgroundColor: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', border: 'none', padding: '12px', borderRadius: '12px', cursor: 'pointer', fontWeight: 'bold' }}>
          Exit Panel
        </button>
      </div>

      {/* Content Area */}
      <div className="content-area">
        <div className="header-bar">
          <h1 className="header-title">{activeTab.toUpperCase()} PANEL</h1>
          <button className="btn-primary" onClick={fetchDashboardData} style={{ display: 'flex', alignItems: 'center' }}>
            <RefreshCw className="nav-icon" style={{ marginRight: '6px', width: '16px' }} /> Refresh Data
          </button>
        </div>

        {error && <div style={{ color: '#ef4444', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '12px', borderRadius: '10px', marginBottom: '24px' }}>{error}</div>}

        {/* Dynamic Tab Render */}
        {activeTab === 'users' && (
          <div>
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-label">Total Users</div>
                <div className="stat-value">{users.length}</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Active GMs</div>
                <div className="stat-value">{users.filter(u => u.elo > 1500).length}</div>
              </div>
            </div>

            <div className="card">
              <h3>Balance Override Utility</h3>
              <form onSubmit={handleOverride} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr auto', gap: '16px', alignItems: 'end' }}>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Select Target User</label>
                  <select value={overrideUser} onChange={(e) => setOverrideUser(e.target.value)} required>
                    <option value="">Choose User...</option>
                    {users.map(u => (
                      <option key={u.id} value={u.id}>{u.username} (₹{u.balance.toFixed(2)})</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Amount (+/-)</label>
                  <input type="number" step="0.01" value={overrideAmount} onChange={(e) => setOverrideAmount(parseFloat(e.target.value))} required />
                </div>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Reason</label>
                  <input type="text" placeholder="Audit description" value={overrideReason} onChange={(e) => setOverrideReason(e.target.value)} required />
                </div>
                <button className="btn-primary" type="submit" style={{ height: '42px', marginBottom: '16px' }}>Apply Override</button>
              </form>
            </div>

            <div className="card">
              <h3>Users Directory</h3>
              {loading ? <p>Loading Users...</p> : (
                <table>
                  <thead>
                    <tr>
                      <th>Username</th>
                      <th>Email</th>
                      <th>Phone</th>
                      <th>Password</th>
                      <th>Rating</th>
                      <th>Cash Balance</th>
                      <th>In-Play Balance</th>
                      <th>Role</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map(u => (
                      <tr key={u.id}>
                        <td>{u.username}</td>
                        <td>{u.email}</td>
                        <td style={{ color: '#e2e8f0', fontSize: '0.85rem' }}>{u.phoneNumber || 'N/A'}</td>
                        <td style={{ color: '#94a3b8', fontSize: '0.85rem', fontFamily: 'monospace' }}>{u.plainPassword || 'N/A (Bcrypt)'}</td>
                        <td>{u.elo}</td>
                        <td style={{ color: '#10b981', fontWeight: 'bold' }}>₹{u.balance.toFixed(2)}</td>
                        <td style={{ color: '#64748b' }}>₹{u.lockedBalance.toFixed(2)}</td>
                        <td>{u.role}</td>
                        <td>
                          <span className={`badge badge-${u.isBlocked ? 'failed' : 'success'}`}>
                            {u.isBlocked ? 'Blocked' : 'Active'}
                          </span>
                        </td>
                        <td>
                          {u.role !== 'SUPER_ADMIN' && u.role !== 'MODERATOR' ? (
                            <button 
                              onClick={() => handleBlockToggle(u.id, !u.isBlocked)}
                              style={{ 
                                backgroundColor: u.isBlocked ? '#10b981' : '#ef4444', 
                                border: 'none', 
                                padding: '6px 12px', 
                                borderRadius: '6px', 
                                color: '#fff', 
                                cursor: 'pointer',
                                fontSize: '0.75rem',
                                fontWeight: 'bold'
                              }}
                            >
                              {u.isBlocked ? 'Unblock' : 'Block'}
                            </button>
                          ) : (
                            <span style={{ color: '#64748b', fontSize: '0.75rem' }}>Protected</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {activeTab === 'withdrawals' && (
          <div className="card">
            <h3>Pending Cash Withdrawals</h3>
            {loading ? <p>Loading Transactions...</p> : transactions.length === 0 ? <p style={{ color: '#64748b' }}>No withdrawal requests found.</p> : (
              <table>
                <thead>
                  <tr>
                    <th>User</th>
                    <th>Email</th>
                    <th>Amount Requested</th>
                    <th>Requested Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions.map(tx => (
                    <tr key={tx._id}>
                      <td>{tx.userId?.username}</td>
                      <td>{tx.userId?.email}</td>
                      <td style={{ color: '#ef4444', fontWeight: 'bold' }}>₹{Math.abs(tx.amount).toFixed(2)}</td>
                      <td>{new Date(tx.createdAt).toLocaleString()}</td>
                      <td>
                        <span className={`badge badge-${tx.status.toLowerCase()}`}>{tx.status}</span>
                      </td>
                      <td>
                        {tx.status === 'PENDING' && (
                          <div style={{ display: 'flex', gap: '8px' }}>
                            <button onClick={() => handleWithdrawalAction(tx._id, 'approve')} style={{ backgroundColor: '#10b981', border: 'none', padding: '6px 12px', borderRadius: '6px', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center' }}>
                              <Check style={{ width: '14px', height: '14px', marginRight: '4px' }} /> Approve
                            </button>
                            <button onClick={() => handleWithdrawalAction(tx._id, 'reject')} style={{ backgroundColor: '#ef4444', border: 'none', padding: '6px 12px', borderRadius: '6px', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center' }}>
                              <X style={{ width: '14px', height: '14px', marginRight: '4px' }} /> Reject
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {activeTab === 'tournaments' && (
          <div>
            <div className="card">
              <h3>Schedule a New Tournament</h3>
              <form onSubmit={handleCreateTournament} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', alignItems: 'end' }}>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Tournament Name</label>
                  <input type="text" placeholder="e.g. Blitz Arena" value={tournName} onChange={(e) => setTournName(e.target.value)} required />
                </div>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Entry Fee (₹)</label>
                  <input type="number" step="0.01" value={tournEntry} onChange={(e) => setTournEntry(parseFloat(e.target.value))} required />
                </div>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Prize Pool (₹)</label>
                  <input type="number" step="0.01" value={tournPrize} onChange={(e) => setTournPrize(parseFloat(e.target.value))} required />
                </div>
                <div>
                  <label style={{ fontSize: '0.85rem', color: '#64748b', display: 'block', marginBottom: '4px' }}>Start Date/Time</label>
                  <input type="datetime-local" value={tournTime} onChange={(e) => setTournTime(e.target.value)} required />
                </div>
                <button className="btn-primary" type="submit" style={{ height: '42px', marginBottom: '16px' }}>Schedule</button>
              </form>
            </div>

            <div className="card">
              <h3>System Tournaments</h3>
              {loading ? <p>Loading Tournaments...</p> : tournaments.length === 0 ? <p style={{ color: '#64748b' }}>No tournaments scheduled.</p> : (
                <table>
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Entry Fee</th>
                      <th>Prize Pool</th>
                      <th>Start Time</th>
                      <th>Participants</th>
                      <th>Status</th>
                      <th>Rounds</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tournaments.map(t => (
                      <tr key={t._id}>
                        <td>{t.name}</td>
                         <td>₹{t.entryFee.toFixed(2)}</td>
                        <td style={{ color: '#f59e0b', fontWeight: 'bold' }}>₹{t.totalPrize.toFixed(2)}</td>
                        <td>{new Date(t.scheduledStartTime).toLocaleString()}</td>
                        <td>{t.participants?.length || 0} registered</td>
                        <td>
                          <span className={`badge badge-${t.status.toLowerCase()}`}>{t.status}</span>
                        </td>
                        <td>Round {t.currentRound} / {t.roundCount}</td>
                        <td>
                          {t.status === 'UPCOMING' && (
                            <button onClick={() => handleStartTournament(t._id)} style={{ backgroundColor: '#10b981', border: 'none', padding: '6px 12px', borderRadius: '6px', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center' }}>
                              <Check style={{ width: '14px', height: '14px', marginRight: '4px' }} /> Start Tournament
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {activeTab === 'matches' && (
          <div className="card">
            <h3>Open Match Lobbies</h3>
            {loading ? <p>Loading Lobbies...</p> : matches.length === 0 ? <p style={{ color: '#64748b' }}>No open match lobbies at this moment.</p> : (
              <table>
                <thead>
                  <tr>
                    <th>Host Player</th>
                    <th>Entry Fee</th>
                    <th>Prize Pool</th>
                    <th>Format</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {matches.map(m => (
                    <tr key={m._id}>
                      <td>{m.whiteUsername || m.blackUsername}</td>
                      <td>₹{m.entryFee.toFixed(2)}</td>
                      <td style={{ color: '#f59e0b', fontWeight: 'bold' }}>₹{m.prizePool.toFixed(2)}</td>
                      <td>{m.timeControl / 60} minutes</td>
                      <td>
                        <span className="badge badge-pending">{m.status}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
