// ==============================================================================
// 🧠 NEXUS OPS WEB APPLICATION — MAIN CONTROLLER (ESM)
// ==============================================================================
import { initializeApp } from 'firebase/app';
import { 
    getAuth, 
    signInWithEmailAndPassword, 
    createUserWithEmailAndPassword, 
    signOut, 
    onAuthStateChanged 
} from 'firebase/auth';
import { 
    getFirestore, 
    doc, 
    setDoc, 
    getDoc, 
    collection, 
    addDoc, 
    serverTimestamp, 
    query, 
    orderBy, 
    onSnapshot 
} from 'firebase/firestore';

// ── 1. Firebase Config Setup (Mirrors Mobile App) ───────────────────────────
const firebaseConfig = {
    apiKey: 'AIzaSyDxwA1myGUAJfQMV9nSZKRDNfquJf1b_RM',
    authDomain: 'ai-seekho-e66dc.firebaseapp.com',
    projectId: 'ai-seekho-e66dc',
    storageBucket: 'ai-seekho-e66dc.firebasestorage.app',
    messagingSenderId: '955785962137',
    appId: '1:955785962137:web:cf00dc72cb506d4f938e08',
    measurementId: 'G-ET26HYV64L'
};

// Initialize Firebase services
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// Deployed Backend API Endpoint
const API_BASE = 'https://ai-seekho-backend-1000940240202.us-central1.run.app';

// ── 2. Local State Management ────────────────────────────────────────────────
let currentUser = null;
let currentInputMode = 'text'; // 'text' | 'pdf'
let selectedFile = null;
let selectedFileBuffer = null;
let historyUnsubscribe = null;

// Initialize Lucide icons on DOM Load
document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
    initEventListeners();
});

// ── 3. DOM Elements Cache ───────────────────────────────────────────────────
const dom = {
    authContainer: document.getElementById('authContainer'),
    appContainer: document.getElementById('appContainer'),
    authForm: document.getElementById('authForm'),
    authTitle: document.getElementById('authTitle'),
    authSubtitle: document.getElementById('authSubtitle'),
    authSubmitBtn: document.getElementById('authSubmitBtn'),
    authToggleBtn: document.getElementById('authToggleBtn'),
    authToggleHint: document.getElementById('authToggleHint'),
    nameFieldGroup: document.getElementById('nameFieldGroup'),
    regName: document.getElementById('regName'),
    authEmail: document.getElementById('authEmail'),
    authPassword: document.getElementById('authPassword'),
    authErrorAlert: document.getElementById('authErrorAlert'),
    authErrorMsg: document.getElementById('authErrorMsg'),
    
    // Header & User previews
    currentTabLabel: document.getElementById('currentTabLabel'),
    userAvatarChar: document.getElementById('userAvatarChar'),
    userPreviewName: document.getElementById('userPreviewName'),
    logoutBtn: document.getElementById('logoutBtn'),
    
    // View sections
    views: {
        operations: document.getElementById('viewOperations'),
        history: document.getElementById('viewHistory'),
        profile: document.getElementById('viewProfile')
    },
    
    // Operations Elements
    modeTextBtn: document.getElementById('modeTextBtn'),
    modePdfBtn: document.getElementById('modePdfBtn'),
    opsTextInputArea: document.getElementById('opsTextInputArea'),
    opsPdfInputArea: document.getElementById('opsPdfInputArea'),
    opsTextContent: document.getElementById('opsTextContent'),
    dropzone: document.getElementById('dropzone'),
    pdfFileInput: document.getElementById('pdfFileInput'),
    fileSelectionBadge: document.getElementById('fileSelectionBadge'),
    selectedFileName: document.getElementById('selectedFileName'),
    removeSelectedFile: document.getElementById('removeSelectedFile'),
    runPipelineBtn: document.getElementById('runPipelineBtn'),
    opsErrorAlert: document.getElementById('opsErrorAlert'),
    opsErrorMsg: document.getElementById('opsErrorMsg'),
    telemetryStepper: document.getElementById('telemetryStepper'),
    
    // Steps
    steps: {
        ie: document.getElementById('stepIE'),
        da: document.getElementById('stepDA'),
        es: document.getElementById('stepES')
    },
    
    // Results
    pipelineResultsFrame: document.getElementById('pipelineResultsFrame'),
    resInsightAnomaly: document.getElementById('resInsightAnomaly'),
    resInsightCause: document.getElementById('resInsightCause'),
    resImpactSeverity: document.getElementById('resImpactSeverity'),
    resImpactImplication: document.getElementById('resImpactImplication'),
    resImpactRisk: document.getElementById('resImpactRisk'),
    resActionTitle: document.getElementById('resActionTitle'),
    resActionReasoning: document.getElementById('resActionReasoning'),
    resActionType: document.getElementById('resActionType'),
    resForecastContainer: document.getElementById('resForecastContainer'),
    
    // History
    historyList: document.getElementById('historyList'),
    
    // Profile Forms
    profileForm: document.getElementById('profileForm'),
    profileName: document.getElementById('profileName'),
    profileEmail: document.getElementById('profileEmail'),
    profileAvatarChar: document.getElementById('profileAvatarChar'),
    profileHeaderName: document.getElementById('profileHeaderName'),
    profileHeaderEmail: document.getElementById('profileHeaderEmail'),
    saveProfileBtn: document.getElementById('saveProfileBtn'),
    profileSuccessAlert: document.getElementById('profileSuccessAlert'),
    
    // Webhook Forms
    profileWebhook: document.getElementById('profileWebhook'),
    saveWebhookBtn: document.getElementById('saveWebhookBtn'),
    webhookSuccessAlert: document.getElementById('webhookSuccessAlert')
};

// ── 4. Main Tab Router ────────────────────────────────────────────────────────
window.switchView = function(viewName, element) {
    // Update Sidebar Navigation state
    document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active'));
    if (element) {
        element.classList.add('active');
    }
    
    // Update layout header label
    let niceNames = { operations: 'Operations Flow', history: 'Run History', profile: 'Profile Settings' };
    dom.currentTabLabel.innerText = niceNames[viewName] || 'Dashboard';
    
    // Switch active view visibility
    Object.keys(dom.views).forEach(key => {
        if (key === viewName) {
            dom.views[key].classList.add('active');
        } else {
            dom.views[key].classList.remove('active');
        }
    });

    // Sub-routine loads
    if (viewName === 'profile') {
        loadUserProfile();
    }
};

// ── 5. Firebase Auth Engine ──────────────────────────────────────────────────
let isLoginMode = true;

function initEventListeners() {
    // Auth Toggle
    dom.authToggleBtn.addEventListener('click', (e) => {
        e.preventDefault();
        isLoginMode = !isLoginMode;
        
        if (isLoginMode) {
            dom.authTitle.innerText = "Antigravity Ops";
            dom.authSubtitle.innerText = "Please log in to access the agentic console";
            dom.nameFieldGroup.classList.add('hidden');
            dom.authSubmitBtn.querySelector('span').innerText = "Sign In";
            dom.authToggleHint.innerText = "Don't have an account?";
            dom.authToggleBtn.innerText = "Create account";
        } else {
            dom.authTitle.innerText = "Create Account";
            dom.authSubtitle.innerText = "Sign up to begin business operational tasks";
            dom.nameFieldGroup.classList.remove('hidden');
            dom.authSubmitBtn.querySelector('span').innerText = "Register Account";
            dom.authToggleHint.innerText = "Already registered?";
            dom.authToggleBtn.innerText = "Sign In instead";
        }
        dom.authErrorAlert.classList.add('hidden');
    });

    // Auth Submission
    dom.authForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        dom.authErrorAlert.classList.add('hidden');
        
        const email = dom.authEmail.value.trim();
        const password = dom.authPassword.value;
        
        // Show Loading UI state
        setBtnLoading(dom.authSubmitBtn, true, isLoginMode ? 'Signing In...' : 'Registering...');

        try {
            if (isLoginMode) {
                // Sign In
                await signInWithEmailAndPassword(auth, email, password);
            } else {
                // Register
                const name = dom.regName.value.trim();
                if (!name) {
                    throw new Error("Please enter your full name.");
                }
                const userCredential = await createUserWithEmailAndPassword(auth, email, password);
                const user = userCredential.user;
                
                // Write user meta document in Firestore
                await setDoc(doc(db, "users", user.uid), {
                    name: name,
                    email: email,
                    role: "operations_admin",
                    webhookUrl: ""
                }, { merge: true });
            }
        } catch (error) {
            console.error("Auth Failure: ", error);
            dom.authErrorMsg.innerText = getFriendlyAuthError(error.message);
            dom.authErrorAlert.classList.remove('hidden');
        } finally {
            setBtnLoading(dom.authSubmitBtn, false, isLoginMode ? 'Sign In' : 'Register Account');
        }
    });

    // Sign Out trigger
    dom.logoutBtn.addEventListener('click', () => {
        signOut(auth);
    });

    // ── Mode selection ──
    dom.modeTextBtn.addEventListener('click', () => {
        currentInputMode = 'text';
        dom.modeTextBtn.classList.add('active');
        dom.modePdfBtn.classList.remove('active');
        dom.opsTextInputArea.classList.remove('hidden');
        dom.opsPdfInputArea.classList.add('hidden');
        dom.opsErrorAlert.classList.add('hidden');
    });

    dom.modePdfBtn.addEventListener('click', () => {
        currentInputMode = 'pdf';
        dom.modePdfBtn.classList.add('active');
        dom.modeTextBtn.classList.remove('active');
        dom.opsPdfInputArea.classList.remove('hidden');
        dom.opsTextInputArea.classList.add('hidden');
        dom.opsErrorAlert.classList.add('hidden');
    });

    // ── PDF Dropzone Handlers ──
    dom.dropzone.addEventListener('click', () => dom.pdfFileInput.click());
    
    dom.pdfFileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleSelectedFile(e.target.files[0]);
        }
    });

    dom.dropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dom.dropzone.classList.add('dragover');
    });

    dom.dropzone.addEventListener('dragleave', () => {
        dom.dropzone.classList.remove('dragover');
    });

    dom.dropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        dom.dropzone.classList.remove('dragover');
        if (e.dataTransfer.files.length > 0) {
            handleSelectedFile(e.dataTransfer.files[0]);
        }
    });

    dom.removeSelectedFile.addEventListener('click', (e) => {
        e.stopPropagation();
        selectedFile = null;
        selectedFileBuffer = null;
        dom.fileSelectionBadge.classList.add('hidden');
        dom.dropzone.classList.remove('hidden');
        dom.pdfFileInput.value = '';
    });

    // ── Operations Flow Execute ──
    dom.runPipelineBtn.addEventListener('click', executeOpsPipeline);

    // ── Profile Updates ──
    dom.profileForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const newName = dom.profileName.value.trim();
        if (!newName) return;
        
        setBtnLoading(dom.saveProfileBtn, true, 'Saving...');
        dom.profileSuccessAlert.classList.add('hidden');

        try {
            await setDoc(doc(db, "users", currentUser.uid), {
                name: newName
            }, { merge: true });
            
            // Sync local header UI dynamically
            dom.userPreviewName.innerText = newName;
            dom.profileHeaderName.innerText = newName;
            dom.userAvatarChar.innerText = newName.charAt(0).toUpperCase();
            dom.profileAvatarChar.innerText = newName.charAt(0).toUpperCase();
            
            dom.profileSuccessAlert.classList.remove('hidden');
            setTimeout(() => dom.profileSuccessAlert.classList.add('hidden'), 3000);
        } catch (err) {
            console.error("Profile save error: ", err);
        } finally {
            setBtnLoading(dom.saveProfileBtn, false, 'Save Profile');
        }
    });

    // ── Discord webhook save ──
    dom.saveWebhookBtn.addEventListener('click', async () => {
        const url = dom.profileWebhook.value.trim();
        setBtnLoading(dom.saveWebhookBtn, true, 'Saving Webhook...');
        dom.webhookSuccessAlert.classList.add('hidden');

        try {
            await setDoc(doc(db, "users", currentUser.uid), {
                webhookUrl: url
            }, { merge: true });
            
            dom.webhookSuccessAlert.classList.remove('hidden');
            setTimeout(() => dom.webhookSuccessAlert.classList.add('hidden'), 3000);
        } catch (err) {
            console.error("Webhook save error: ", err);
        } finally {
            setBtnLoading(dom.saveWebhookBtn, false, 'Save Integration');
        }
    });
}

// Global Auth State Observer
onAuthStateChanged(auth, (user) => {
    if (user) {
        // Authenticated! Mount the core app viewport
        currentUser = user;
        dom.authContainer.style.display = 'none';
        dom.appContainer.style.display = 'grid';
        
        // Load settings and real-time streams
        initUserContext();
        subscribeToHistoryStream();

        // Always default to the Main Operations Flow view after successful login
        const opsNavLink = document.querySelector('.nav-link[onclick*="operations"]');
        switchView('operations', opsNavLink);
    } else {
        // Disconnected. Mount credentials landing card
        currentUser = null;
        dom.authContainer.style.display = 'flex';
        dom.appContainer.style.display = 'none';
        
        // Reset local variables
        if (historyUnsubscribe) {
            historyUnsubscribe();
            historyUnsubscribe = null;
        }
    }
});

// Setup dynamic view meta details
async function initUserContext() {
    dom.profileEmail.value = currentUser.email;
    dom.profileHeaderEmail.innerText = currentUser.email;

    try {
        const userDoc = await getDoc(doc(db, "users", currentUser.uid));
        if (userDoc.exists()) {
            const data = userDoc.data();
            const name = data.name || 'Operations Admin';
            dom.userPreviewName.innerText = name;
            dom.profileHeaderName.innerText = name;
            dom.profileName.value = name;
            dom.userAvatarChar.innerText = name.charAt(0).toUpperCase();
            dom.profileAvatarChar.innerText = name.charAt(0).toUpperCase();
            
            // Discord Webhook
            dom.profileWebhook.value = data.webhookUrl || '';
        }
    } catch (e) {
        console.error("User context init error: ", e);
    }
}

// ── 6. PDF Reader ────────────────────────────────────────────────────────────
function handleSelectedFile(file) {
    if (file.type !== 'application/pdf') {
        alert('Only PDF documents are supported!');
        return;
    }
    
    selectedFile = file;
    dom.selectedFileName.innerText = file.name;
    dom.fileSelectionBadge.classList.remove('hidden');
    dom.dropzone.classList.add('hidden');
    dom.opsErrorAlert.classList.add('hidden');

    const reader = new FileReader();
    reader.onload = (e) => {
        selectedFileBuffer = e.target.result;
    };
    reader.readAsArrayBuffer(file);
}

// ── 7. Operations Execution Flow ─────────────────────────────────────────────
async function executeOpsPipeline() {
    dom.opsErrorAlert.classList.add('hidden');
    dom.pipelineResultsFrame.classList.add('hidden');

    // Validation checks
    const textInput = dom.opsTextContent.value.trim();
    if (currentInputMode === 'text' && !textInput) {
        showOpsError("Please enter a business report, url context, or incident details.");
        return;
    }
    if (currentInputMode === 'pdf' && !selectedFileBuffer) {
        showOpsError("Please select and load a PDF document first.");
        return;
    }

    // Toggle loader stepping telemetry
    dom.telemetryStepper.classList.remove('hidden');
    setStepState('ie', 'active');
    setStepState('da', 'inactive');
    setStepState('es', 'inactive');
    
    // Disable main CTA
    setBtnLoading(dom.runPipelineBtn, true, 'Orchestrating agents...');
    
    try {
        // Fetch discord webhook from Firestore configuration
        let webhookUrl = '';
        const docSnap = await getDoc(doc(db, "users", currentUser.uid));
        if (docSnap.exists()) {
            webhookUrl = docSnap.data().webhookUrl || '';
        }

        let resultData = null;

        if (currentInputMode === 'text') {
            // Send standard HTTP Text payload
            const response = await fetch(`${API_BASE}/api/v1/test/analyze`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    source: 'web_application',
                    data_type: 'text/plain',
                    content: textInput,
                    webhook_url: webhookUrl
                })
            });

            if (!response.ok) {
                const errBody = await response.json();
                throw new Error(errBody.detail || `Server responded with ${response.status}`);
            }
            resultData = await response.json();

        } else {
            // Send Multipart PDF payload
            const formData = new FormData();
            
            // Build direct Blob payload from arrayBuffer
            const fileBlob = new Blob([selectedFileBuffer], { type: 'application/pdf' });
            formData.append('file', fileBlob, selectedFile.name);
            
            if (textInput) {
                formData.append('text', textInput);
            }
            if (webhookUrl) {
                formData.append('webhook_url', webhookUrl);
            }

            // Move stepper status forward
            setStepState('ie', 'completed');
            setStepState('da', 'active');

            const response = await fetch(`${API_BASE}/api/v1/test/upload`, {
                method: 'POST',
                body: formData
            });

            if (!response.ok) {
                const errBody = await response.json();
                throw new Error(errBody.detail || `File analysis failed with HTTP ${response.status}`);
            }
            resultData = await response.json();
        }

        // Drive dynamic telemetries forward on successful response
        setStepState('ie', 'completed');
        setStepState('da', 'completed');
        setStepState('es', 'active');
        
        setTimeout(() => {
            setStepState('es', 'completed');
            renderPipelineResults(resultData);
            
            // Log run results directly to Firebase Shared Firestore Stream
            saveRunHistoryToFirestore(textInput, resultData);
            
            setBtnLoading(dom.runPipelineBtn, false, 'Run Agentic Flow');
            dom.telemetryStepper.classList.add('hidden');
        }, 1200);

    } catch (error) {
        console.error("Orchestrator pipeline error: ", error);
        showOpsError(error.message || "An unexpected error occurred connecting to the backend.");
        setBtnLoading(dom.runPipelineBtn, false, 'Run Agentic Flow');
        dom.telemetryStepper.classList.add('hidden');
    }
}

// ── 8. Telemetry Rendering Engine ────────────────────────────────────────────
function setStepState(stepKey, state) {
    const el = dom.steps[stepKey];
    if (!el) return;
    
    el.classList.remove('active', 'completed');
    if (state === 'active') el.classList.add('active');
    if (state === 'completed') el.classList.add('completed');
}

function showOpsError(msg) {
    dom.opsErrorMsg.innerText = msg;
    dom.opsErrorAlert.classList.remove('hidden');
    dom.opsErrorAlert.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// Render dynamic agent cards outputs
function renderPipelineResults(r) {
    const insight = r.insight || {};
    const impact = r.impact || {};
    const action = r.recommended_action || {};
    
    // Insight Card
    dom.resInsightAnomaly.innerText = insight.anomaly || 'N/A';
    dom.resInsightCause.innerText = `Root Cause: ${insight.primary_cause || 'N/A'}`;
    
    // Impact Card
    const severity = (impact.severity || 'LOW').toUpperCase();
    dom.resImpactSeverity.innerText = `Severity: ${severity}`;
    
    // Assign structural color tags
    dom.resImpactSeverity.className = 'severity-indicator';
    if (severity === 'CRITICAL') dom.resImpactSeverity.classList.add('severity-critical');
    else if (severity === 'HIGH') dom.resImpactSeverity.classList.add('severity-high');
    else if (severity === 'MEDIUM') dom.resImpactSeverity.classList.add('severity-medium');
    else dom.resImpactSeverity.classList.add('severity-low');
    
    dom.resImpactImplication.innerText = impact.strategic_implication || 'N/A';
    dom.resImpactRisk.innerText = `Risk Estimate: ${impact.financial_risk_estimate || 'N/A'}`;
    
    // Action Card
    dom.resActionTitle.innerText = action.action_title || action.action_type || 'Custom Recommendation';
    dom.resActionReasoning.innerText = `"${action.decision_reasoning || 'No details provided.'}"`;
    dom.resActionType.innerText = `TYPE: ${action.action_type || 'N/A'}`;
    
    // Outcomes Card
    const outcomes = action.projected_outcomes || [];
    dom.resForecastContainer.innerHTML = '';
    
    if (outcomes.length === 0) {
        dom.resForecastContainer.innerHTML = `<div style="color: var(--text-muted); font-size: 13px;">No metric changes simulated.</div>`;
    } else {
        outcomes.forEach(o => {
            const item = document.createElement('div');
            item.className = 'forecast-item';
            item.innerHTML = `
                <div class="forecast-metric">${o.metric || 'KPI'}</div>
                <div class="forecast-state">
                    <span class="state-before">${o.before_state || 'Before'}</span>
                    <span class="state-arrow">➔</span>
                    <span class="state-after">${o.after_state || 'After'}</span>
                </div>
            `;
            dom.resForecastContainer.appendChild(item);
        });
    }

    // Animate view frame open
    dom.pipelineResultsFrame.classList.remove('hidden');
    dom.pipelineResultsFrame.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    
    lucide.createIcons();
}

// ── 9. Firebase Shared History Operations ──────────────────────────────────
async function saveRunHistoryToFirestore(rawInput, result) {
    try {
        const inputLabel = currentInputMode === 'text' ? rawInput : (selectedFile ? selectedFile.name : 'Uploaded PDF');
        
        await addDoc(collection(db, "users", currentUser.uid, "history"), {
            timestamp: serverTimestamp(),
            input: inputLabel.substring(0, 150),
            insight: {
                anomaly: result.insight?.anomaly || 'Analysis Complete',
                primary_cause: result.insight?.primary_cause || ''
            },
            severity: result.impact?.severity || 'LOW',
            action: {
                action_title: result.recommended_action?.action_title || result.recommended_action?.action_type || 'No action needed',
                decision_reasoning: result.recommended_action?.decision_reasoning || '',
                action_type: result.recommended_action?.action_type || ''
            }
        });
    } catch (e) {
        console.error("Firestore history logger failure: ", e);
    }
}

// ── 10. Real-time Firestore History Streamer ────────────────────────────────
function subscribeToHistoryStream() {
    if (historyUnsubscribe) {
        historyUnsubscribe();
    }

    const historyQuery = query(
        collection(db, "users", currentUser.uid, "history"),
        orderBy("timestamp", "desc")
    );

    historyUnsubscribe = onSnapshot(historyQuery, (snapshot) => {
        dom.historyList.innerHTML = '';

        if (snapshot.empty) {
            dom.historyList.innerHTML = `
                <div style="text-align: center; padding: 40px; color: var(--text-muted);">
                    <i data-lucide="history" style="width: 44px; height: 44px; margin-bottom: 12px; opacity: 0.5;"></i>
                    <h3 style="font-size: 15px; font-weight: 600; color: var(--text-sub); margin-bottom: 4px;">No session runs found</h3>
                    <p style="font-size: 12px;">Trigger your very first analysis on the Operations Flow tab!</p>
                </div>
            `;
            lucide.createIcons();
            return;
        }

        snapshot.forEach((docSnap) => {
            const data = docSnap.data();
            const id = docSnap.id;
            const shortId = id.substring(0, 8).toUpperCase();
            
            // Format timestamps cleanly
            let dateStr = 'Just now';
            if (data.timestamp) {
                const d = data.timestamp.toDate();
                dateStr = d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }

            // Extract nested properties safely (mirrors mobile logic)
            const title = asDisplayString(data.input, 'Analyzed Context');
            const insightText = asDisplayString(data.insight);
            const actionText = asDisplayString(data.action);
            const severity = (data.severity || 'LOW').toUpperCase();

            // Format URL vs Text beautifully
            let titleHtml = escapeHtml(title);
            const trimmedTitle = title.trim();
            const lowerTitle = trimmedTitle.toLowerCase();
            if (lowerTitle.startsWith('http://') || lowerTitle.startsWith('https://') || lowerTitle.startsWith('www.')) {
                const hrefUrl = lowerTitle.startsWith('www.') ? `https://${trimmedTitle}` : trimmedTitle;
                titleHtml = `<span class="url-box" onclick="event.stopPropagation();"><i data-lucide="external-link" class="url-icon"></i><a href="${escapeHtml(hrefUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(trimmedTitle)}</a></span>`;
            }

            // Construct gorgeous collapsible UI tile
            const tile = document.createElement('div');
            tile.className = 'history-tile';
            tile.innerHTML = `
                <div class="history-tile-header" onclick="this.parentElement.classList.toggle('expanded')">
                    <div class="history-tile-icon">
                        <i data-lucide="zap"></i>
                    </div>
                    <div class="history-tile-info">
                        <h3 class="history-tile-title">${titleHtml}</h3>
                        <div class="history-tile-date">${dateStr}</div>
                    </div>
                    <span class="severity-indicator severity-${severity.toLowerCase()}" style="margin-bottom:0; margin-right:10px;">${severity}</span>
                    <i data-lucide="chevron-down" class="history-tile-chevron"></i>
                </div>
                <div class="history-tile-details">
                    <div class="tile-detail-section">
                        <div class="tile-detail-label">🧠 Insight</div>
                        <div class="tile-detail-value">${escapeHtml(insightText)}</div>
                    </div>
                    <div class="tile-detail-section">
                        <div class="tile-detail-label">🎯 Action Executed</div>
                        <div class="tile-detail-value">${escapeHtml(actionText)}</div>
                    </div>
                    <div class="tile-detail-section" style="border-top: 1px solid var(--border); padding-top: 10px; margin-top: 12px; display:flex; gap:8px; font-size:11px; color: var(--text-muted);">
                        <span>Session ID:</span>
                        <span style="font-family: monospace; font-weight:600; color: var(--text-sub);">${shortId}</span>
                    </div>
                </div>
            `;
            dom.historyList.appendChild(tile);
        });

        lucide.createIcons();
    }, (error) => {
        console.error("Firestore history stream error: ", error);
        dom.historyList.innerHTML = `<div style="color: var(--danger); font-size: 13px;">Error loading live history logs.</div>`;
    });
}

// ── 11. Profile Loader Sub-routines ──────────────────────────────────────────
async function loadUserProfile() {
    try {
        const snap = await getDoc(doc(db, "users", currentUser.uid));
        if (snap.exists()) {
            const data = snap.data();
            dom.profileName.value = data.name || '';
            dom.profileWebhook.value = data.webhookUrl || '';
        }
    } catch (e) {
        console.error("Failed loading user profile: ", e);
    }
}

// ── 12. Dynamic Utility Helpers ────────────────────────────────────────────────
function setBtnLoading(btn, isLoading, text) {
    const label = btn.querySelector('span');
    if (isLoading) {
        btn.disabled = true;
        btn.style.opacity = '0.7';
        btn.style.cursor = 'not-allowed';
        if (label) label.innerText = text;
    } else {
        btn.disabled = false;
        btn.style.opacity = '1';
        btn.style.cursor = 'pointer';
        if (label) label.innerText = text;
    }
}

function getFriendlyAuthError(errCode) {
    if (errCode.includes('auth/invalid-credential') || errCode.includes('auth/wrong-password') || errCode.includes('auth/user-not-found')) {
        return "Invalid email address or operational password. Please check credentials.";
    }
    if (errCode.includes('auth/email-already-in-use')) {
        return "This administrator email is already registered inside Firestore Auth.";
    }
    if (errCode.includes('auth/weak-password')) {
        return "Security policy: Password must be at least 6 characters in length.";
    }
    return errCode;
}

function asDisplayString(value, fallback = 'N/A') {
    if (!value) return fallback;
    if (typeof value === 'string') return value.length === 0 ? fallback : value;
    if (typeof value === 'object') {
        for (const key of ['anomaly', 'action_title', 'action_type', 'strategic_implication', 'primary_cause', 'severity']) {
            if (value[key] && value[key].toString().trim().length > 0) {
                return value[key].toString();
            }
        }
    }
    const str = value.toString();
    return str.length === 0 ? fallback : str;
}

function escapeHtml(unsafe) {
    return unsafe
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
}
