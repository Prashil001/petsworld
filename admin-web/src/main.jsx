import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Activity,
  BadgePercent,
  Boxes,
  CheckCircle2,
  ChevronDown,
  Download,
  FileText,
  Home,
  Image,
  LayoutDashboard,
  Loader2,
  LogOut,
  Menu,
  Package,
  Plus,
  ReceiptText,
  Save,
  Search,
  Settings,
  ShieldCheck,
  Tags,
  Trash2,
  Truck,
  X,
} from 'lucide-react';
import { initializeApp } from 'firebase/app';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import './styles.css';

const firebaseConfig = {
  apiKey: 'AIzaSyB-UqDxJADf56zCsgXtY7ioaZYUtCrkgQg',
  authDomain: 'pet-shop-app-ee6f2.firebaseapp.com',
  projectId: 'pet-shop-app-ee6f2',
  storageBucket: 'pet-shop-app-ee6f2.firebasestorage.app',
  messagingSenderId: '119947379250',
  appId: '1:119947379250:web:23c47903302b25eaa7722b',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const cloudinaryConfig = {
  cloudName: 'dezot0sua',
  unsignedUploadPreset: 'pet-shop',
  productFolder: 'petsworld/products',
  categoryFolder: 'petsworld/products/categories',
  bannerFolder: 'petsworld/products/home_banners',
};

const navItems = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'orders', label: 'Orders', icon: ReceiptText },
  { id: 'products', label: 'Products', icon: Package },
  { id: 'categories', label: 'Categories', icon: Boxes },
  { id: 'banners', label: 'Banners', icon: Image },
  { id: 'coupons', label: 'Coupons', icon: Tags },
  { id: 'settings', label: 'Store settings', icon: Settings },
  { id: 'sections', label: 'Home sections', icon: Home },
];

const initialForms = {
  product: {
    id: '',
    name: '',
    brandName: '',
    category: '',
    description: '',
    price: '',
    salePrice: '',
    stockQuantity: '',
    imageUrl: '',
    imageUrls: '',
    packOptions: 'Standard|0||0|default',
    isActive: true,
    isFeatured: false,
    isPopular: false,
    isNewArrival: false,
  },
  category: {
    id: '',
    title: '',
    parentId: '',
    image: '',
    svgSrc: '',
    sortOrder: '',
    isActive: true,
  },
  banner: {
    id: '',
    title: '',
    subtitle: '',
    imageUrl: '',
    actionCategory: '',
    sortOrder: '',
    isActive: true,
  },
  coupon: {
    id: '',
    code: '',
    discountType: 'flatAmount',
    discountValue: '',
    minCartValue: '',
    expiryDate: '',
    usageLimit: '',
    usageCount: '',
    applicableCategoryIds: '',
    applicableProductIds: '',
    isActive: true,
  },
  section: {
    id: '',
    title: '',
    productIds: '',
    sortOrder: '',
    startDate: '',
    endDate: '',
    sectionDiscountType: '',
    sectionDiscountValue: '',
    isActive: true,
  },
};

function App() {
  const [authState, setAuthState] = useState({ loading: true, user: null, admin: false });
  const [active, setActive] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [data, setData] = useState(emptyData());
  const [loadingData, setLoadingData] = useState(false);
  const [toast, setToast] = useState('');

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setAuthState({ loading: false, user: null, admin: false });
        setData(emptyData());
        return;
      }

      try {
        const profile = await getDoc(doc(db, 'users', user.uid));
        const isAdmin = profile.exists() && profile.data()?.role === 'admin';
        if (!isAdmin) {
          await signOut(auth);
          setAuthState({ loading: false, user: null, admin: false });
          setToast('Only admin accounts can access this website.');
          return;
        }
        setAuthState({ loading: false, user, admin: true });
      } catch (error) {
        setAuthState({ loading: false, user: null, admin: false });
        setToast(error.message || 'Unable to verify admin access.');
      }
    });
  }, []);

  useEffect(() => {
    if (authState.admin) {
      loadAllData(setData, setLoadingData, setToast);
    }
  }, [authState.admin]);

  if (authState.loading) {
    return <LoadingScreen message="Opening admin workspace..." />;
  }

  if (!authState.admin) {
    return <LoginScreen toast={toast} clearToast={() => setToast('')} />;
  }

  return (
    <div className="app-shell">
      <Sidebar
        active={active}
        setActive={(id) => {
          setActive(id);
          setSidebarOpen(false);
        }}
        open={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />
      <main className="main">
        <TopBar
          active={active}
          user={authState.user}
          onMenu={() => setSidebarOpen(true)}
          onRefresh={() => loadAllData(setData, setLoadingData, setToast)}
          loading={loadingData}
        />
        <Content
          active={active}
          data={data}
          loading={loadingData}
          refresh={() => loadAllData(setData, setLoadingData, setToast)}
          setToast={setToast}
        />
      </main>
      {toast ? <Toast message={toast} onClose={() => setToast('')} /> : null}
    </div>
  );
}

function LoginScreen({ toast, clearToast }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function submit(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) {
      setError(mapAuthError(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-visual">
        <div className="brand-lockup big">
          <img src="/petsworld_logo.png" alt="PetsWorld" />
          <div>
            <h1>PetsWorld</h1>
            <p>Admin workspace</p>
          </div>
        </div>
        <div className="login-copy">
          <p className="eyebrow">Admin only</p>
          <h2>Manage the store without wrestling the UI.</h2>
          <p>Orders, catalog, banners, coupons, delivery settings, and homepage sections all share the same Firebase data as the app.</p>
        </div>
      </div>
      <form className="login-card" onSubmit={submit}>
        <ShieldCheck size={34} />
        <h2>Sign in</h2>
        <p>Only users with <code>role: admin</code> in Firestore can continue.</p>
        {toast ? <Alert message={toast} onClose={clearToast} /> : null}
        {error ? <Alert message={error} /> : null}
        <label>Email</label>
        <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required autoComplete="username" />
        <label>Password</label>
        <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required autoComplete="current-password" />
        <button className="primary-btn" disabled={loading}>
          {loading ? <Loader2 className="spin" size={18} /> : null}
          Log in as admin
        </button>
      </form>
    </div>
  );
}

function Sidebar({ active, setActive, open, onClose }) {
  return (
    <>
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand-lockup">
          <img src="/petsworld_logo.png" alt="PetsWorld" />
          <div>
            <h1>PetsWorld</h1>
            <p>Admin workspace</p>
          </div>
        </div>
        <nav>
          {navItems.map(({ id, label, icon: Icon }) => (
            <button key={id} onClick={() => setActive(id)} className={active === id ? 'active' : ''}>
              <Icon size={20} />
              <span>{label}</span>
            </button>
          ))}
        </nav>
        <button className="logout-btn" onClick={() => signOut(auth)}>
          <LogOut size={20} /> Sign out
        </button>
      </aside>
      {open ? <button className="scrim" onClick={onClose} aria-label="Close menu" /> : null}
    </>
  );
}

function TopBar({ active, user, onMenu, onRefresh, loading }) {
  const title = navItems.find((item) => item.id === active)?.label || 'Dashboard';
  return (
    <header className="topbar">
      <button className="icon-btn menu-btn" onClick={onMenu}><Menu size={22} /></button>
      <div>
        <p className="eyebrow">PetsWorld Admin</p>
        <h2>{title}</h2>
      </div>
      <div className="top-actions">
        <button className="ghost-btn" onClick={onRefresh} disabled={loading}>
          {loading ? <Loader2 className="spin" size={17} /> : <Activity size={17} />}
          Refresh
        </button>
        <span className="admin-chip">{user?.email}</span>
      </div>
    </header>
  );
}

function Content({ active, data, loading, refresh, setToast }) {
  if (loading) return <LoadingPanel />;
  if (active === 'dashboard') return <Dashboard data={data} setToast={setToast} />;
  if (active === 'orders') return <Orders data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'products') return <Products data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'categories') return <Categories data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'banners') return <Banners data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'coupons') return <Coupons data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'settings') return <StoreSettings data={data} refresh={refresh} setToast={setToast} />;
  if (active === 'sections') return <HomeSections data={data} refresh={refresh} setToast={setToast} />;
  return null;
}

function Dashboard({ data, setToast }) {
  const stats = useMemo(() => buildStats(data), [data]);
  return (
    <section className="page-grid">
      <div className="hero-panel">
        <div>
          <p className="eyebrow">Store control room</p>
          <h1>Everything in one calm workspace.</h1>
          <p>Track orders, manage catalog content, tune checkout settings, and keep the PetsWorld storefront current.</p>
        </div>
        <button className="ghost-btn" onClick={() => exportOrdersCsv(data.orders, setToast)}>
          <Download size={17} /> Export orders
        </button>
      </div>
      <div className="metrics-grid">
        <Metric label="Delivered revenue" value={money(stats.deliveredRevenue)} detail={`${stats.deliveredOrders} delivered orders`} icon={ReceiptText} tone="orange" />
        <Metric label="Open orders" value={stats.openOrders} detail="Placed, confirmed, or shipped" icon={Truck} tone="blue" />
        <Metric label="Catalog" value={data.products.length} detail={`${stats.activeProducts} active, ${stats.featuredProducts} featured`} icon={Package} tone="green" />
        <Metric label="Store setup" value={data.categories.length} detail={`${data.categories.length} categories, ${stats.activeBanners} live banners`} icon={Settings} tone="rose" />
      </div>
      <div className="split-grid">
        <Panel title="Revenue analytics" subtitle="Delivered revenue and open order value">
          <div className="bar-visual">
            <span style={{ height: `${Math.max(8, stats.deliveredRevenue ? 90 : 8)}%` }} />
            <span style={{ height: `${Math.max(10, stats.openValue ? 65 : 10)}%` }} />
            <span style={{ height: `${Math.max(12, stats.averageDeliveredOrder ? 50 : 12)}%` }} />
          </div>
          <div className="mini-grid">
            <MiniStat label="Delivered revenue" value={money(stats.deliveredRevenue)} />
            <MiniStat label="Open-order value" value={money(stats.openValue)} />
            <MiniStat label="Avg delivered" value={money(stats.averageDeliveredOrder)} />
          </div>
        </Panel>
        <Panel title="Order completion" subtitle="Active, delivered, and cancelled">
          <div className="status-stack">
            <Donut total={data.orders.length} cancelled={stats.cancelledOrders} delivered={stats.deliveredOrders} open={stats.openOrders} />
            <Legend label="Open" value={stats.openOrders} tone="blue" />
            <Legend label="Delivered" value={stats.deliveredOrders} tone="orange" />
            <Legend label="Cancelled" value={stats.cancelledOrders} tone="rose" />
          </div>
        </Panel>
      </div>
      <div className="split-grid">
        <Panel title="Recent orders" subtitle="Latest fulfilment activity">
          <CompactTable
            rows={data.orders.slice(0, 5)}
            columns={[
              ['Customer', (o) => o.customerName || o.userName || 'Customer'],
              ['Status', (o) => badge(o.orderStatus || o.status || 'placed')],
              ['Total', (o) => money(orderTotal(o))],
            ]}
          />
        </Panel>
        <Panel title="Top categories" subtitle="Catalog mix">
          {topCategories(data.products).map((item) => (
            <div className="progress-row" key={item.name}>
              <div><b>{item.name}</b><span>{item.count}</span></div>
              <progress value={item.count} max={Math.max(1, data.products.length)} />
            </div>
          ))}
        </Panel>
      </div>
    </section>
  );
}

function Orders({ data, refresh, setToast }) {
  const stats = buildStats(data);
  return (
    <CrudPage
      title="Orders"
      subtitle="Review every order, update fulfilment status, and export order data."
      action={<button className="primary-btn small" onClick={() => exportOrdersCsv(data.orders, setToast)}><Download size={16} /> Export CSV</button>}
    >
      <div className="metrics-grid compact">
        <Metric label="Total orders" value={data.orders.length} detail="All orders" icon={ReceiptText} tone="blue" />
        <Metric label="Open orders" value={stats.openOrders} detail="Placed, confirmed, shipped" icon={Truck} tone="orange" />
        <Metric label="Cancelled" value={stats.cancelledOrders} detail="Locked orders" icon={X} tone="rose" />
        <Metric label="Delivered revenue" value={money(stats.deliveredRevenue)} detail={`${stats.deliveredOrders} delivered`} icon={FileText} tone="green" />
      </div>
      <div className="order-list">
        {data.orders.length ? data.orders.map((order) => (
          <OrderDetailCard key={order.id} order={order} refresh={refresh} setToast={setToast} />
        )) : <div className="empty-state">No orders yet.</div>}
      </div>
    </CrudPage>
  );
}

function OrderDetailCard({ order, refresh, setToast }) {
  const status = order.orderStatus || order.status || 'placed';
  const locked = ['delivered', 'cancelled'].includes(status);
  const address = order.deliveryAddress || {};
  const pricing = order.pricing || {};
  const payment = order.payment || {};
  const items = Array.isArray(order.items) ? order.items : [];
  return (
    <article className="order-card">
      <div className="order-top">
        <div>
          <h3>Order #{order.orderId || order.id}</h3>
          <p>{formatDate(order.createdAt)} · {items.length} line items · {totalItems(order)} units</p>
        </div>
        <div className="pill-row">
          {badge(status)}
          {badge(payment.paymentMethod || order.paymentMethod || 'cod')}
          {badge(payment.paymentStatus || order.paymentStatus || 'pending')}
        </div>
      </div>
      <div className="order-detail-grid">
        <InfoBlock title="Customer" rows={[
          ['Name', order.userName || order.customerName || address.fullName || 'Not provided'],
          ['Email', order.userEmail || 'Not provided'],
          ['Phone', order.userPhone || order.phoneNumber || address.phone || 'Not provided'],
          ['User ID', order.userId || 'Not provided'],
        ]} />
        <InfoBlock title="Delivery address" rows={[
          ['Recipient', address.fullName || order.customerName || 'Not provided'],
          ['Phone', address.phone || order.userPhone || order.phoneNumber || 'Not provided'],
          ['Line 1', address.addressLine1 || order.address || '-'],
          ['Line 2', address.addressLine2 || '-'],
          ['City/State', [address.city, address.state].filter(Boolean).join(', ') || '-'],
          ['Pincode', address.pincode || '-'],
          ['Landmark', address.landmark || '-'],
        ]} />
        <InfoBlock title="Payment and totals" rows={[
          ['Subtotal', money(pricing.subtotal ?? order.subtotal)],
          ['Product discount', money(pricing.productDiscount)],
          ['Coupon', pricing.couponCode || '-'],
          ['Coupon discount', money(pricing.couponDiscount)],
          ['Delivery', money(pricing.deliveryCharge ?? order.deliveryCharge)],
          ['Total', money(orderTotal(order))],
          ['Razorpay payment ID', payment.razorpayPaymentId || '-'],
          ['Razorpay order ID', payment.razorpayOrderId || '-'],
        ]} />
      </div>
      <div className="order-items">
        <h4>Items</h4>
        {items.map((item, index) => (
          <div className="order-item" key={`${item.productId || index}-${index}`}>
            {item.imageUrl ? <img src={item.imageUrl} alt="" /> : <div className="image-placeholder"><Package size={20} /></div>}
            <div>
              <b>{orderItemName(item)}</b>
              <span>Product ID: {item.productId || '-'}</span>
              {item.selectedOptionLabel ? <span>Pack: {item.selectedOptionLabel}</span> : null}
            </div>
            <strong>x{item.quantity || 0}</strong>
            <strong>{money(itemLineTotal(item))}</strong>
          </div>
        ))}
      </div>
      <div className="order-actions">
        <button onClick={() => downloadInvoice(order, setToast)}><FileText size={16} /> Generate invoice</button>
        <label>
          <span>Order status</span>
          <select value={status} disabled={locked} onChange={(e) => updateOrderStatus(order.id, e.target.value, refresh, setToast)}>
            {['placed', 'confirmed', 'shipped', 'delivered', 'cancelled'].map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </label>
        {locked ? <p>Delivered and cancelled orders are locked to protect reporting accuracy.</p> : null}
      </div>
    </article>
  );
}

function InfoBlock({ title, rows }) {
  return <section className="info-block"><h4>{title}</h4>{rows.map(([label, value]) => <div key={label}><span>{label}</span><b>{value}</b></div>)}</section>;
}

function Products({ data, refresh, setToast }) {
  const [form, setForm] = useState(initialForms.product);
  return (
    <CrudPage title="Products" subtitle="Add, edit, hide, feature, and price catalog items.">
      <EditorPanel title={form.id ? 'Edit product' : 'Add product'} onReset={() => setForm(initialForms.product)} onSave={() => saveProduct(form, refresh, setToast, setForm)}>
        <FormGrid>
          <TextInput label="Name" value={form.name} onChange={(name) => setForm({ ...form, name })} />
          <TextInput label="Brand" value={form.brandName} onChange={(brandName) => setForm({ ...form, brandName })} />
          <TextInput label="Category" value={form.category} onChange={(category) => setForm({ ...form, category })} />
          <TextInput label="Price" type="number" value={form.price} onChange={(price) => setForm({ ...form, price })} />
          <TextInput label="Sale price" type="number" value={form.salePrice} onChange={(salePrice) => setForm({ ...form, salePrice })} />
          <TextInput label="Stock" type="number" value={form.stockQuantity} onChange={(stockQuantity) => setForm({ ...form, stockQuantity })} />
          <TextInput label="Image URL" value={form.imageUrl} onChange={(imageUrl) => setForm({ ...form, imageUrl })} wide />
          <ImageUploader label="Upload product image" folder={cloudinaryConfig.productFolder} onUploaded={(url) => setForm((current) => {
            const gallery = csv(current.imageUrls || current.imageUrl);
            const nextGallery = [...gallery, url].slice(0, 5);
            return { ...current, imageUrl: nextGallery[0] || url, imageUrls: nextGallery.join(', ') };
          })} />
          <TextInput label="Gallery URLs (comma separated)" value={form.imageUrls} onChange={(imageUrls) => setForm({ ...form, imageUrls })} wide />
          <TextArea label="Pack options (label|price|salePrice|stock|default, one per line)" value={form.packOptions} onChange={(packOptions) => setForm({ ...form, packOptions })} />
          <TextArea label="Description" value={form.description} onChange={(description) => setForm({ ...form, description })} />
          <Toggle label="Active" checked={form.isActive} onChange={(isActive) => setForm({ ...form, isActive })} />
          <Toggle label="Featured" checked={form.isFeatured} onChange={(isFeatured) => setForm({ ...form, isFeatured })} />
          <Toggle label="Best seller" checked={form.isPopular} onChange={(isPopular) => setForm({ ...form, isPopular })} />
          <Toggle label="New arrival" checked={form.isNewArrival} onChange={(isNewArrival) => setForm({ ...form, isNewArrival })} />
        </FormGrid>
      </EditorPanel>
      <CardGrid>
        {data.products.map((p) => (
          <RecordCard key={p.id} title={p.name || 'Untitled'} image={p.imageUrl} meta={[p.category || 'Unassigned', money(p.price), p.isActive ? 'Active' : 'Hidden']}>
            <button onClick={() => setForm(productToForm(p))}>Edit</button>
            <button className="danger" onClick={() => removeDoc('products', p.id, refresh, setToast)}>Delete</button>
          </RecordCard>
        ))}
      </CardGrid>
    </CrudPage>
  );
}

function Categories({ data, refresh, setToast }) {
  const [form, setForm] = useState(initialForms.category);
  return (
    <CrudPage title="Categories" subtitle="Manage discover hierarchy, parent categories, image URLs, and sort order.">
      <EditorPanel title={form.id ? 'Edit category' : 'Add category'} onReset={() => setForm(initialForms.category)} onSave={() => saveCategory(form, refresh, setToast, setForm)}>
        <FormGrid>
          <TextInput label="Title" value={form.title} onChange={(title) => setForm({ ...form, title })} />
          <TextInput label="Parent ID" value={form.parentId} onChange={(parentId) => setForm({ ...form, parentId })} />
          <TextInput label="Sort order" type="number" value={form.sortOrder} onChange={(sortOrder) => setForm({ ...form, sortOrder })} />
          <TextInput label="Image URL" value={form.image} onChange={(image) => setForm({ ...form, image })} wide />
          <ImageUploader label="Upload category image" folder={cloudinaryConfig.categoryFolder} onUploaded={(url) => setForm((current) => ({ ...current, image: url, svgSrc: url }))} />
          <TextInput label="SVG URL" value={form.svgSrc} onChange={(svgSrc) => setForm({ ...form, svgSrc })} wide />
          <Toggle label="Active" checked={form.isActive} onChange={(isActive) => setForm({ ...form, isActive })} />
        </FormGrid>
      </EditorPanel>
      <DataTable rows={data.categories} columns={[
        ['Title', (c) => <b>{c.title}</b>],
        ['Parent', (c) => c.parentId || '-'],
        ['Sort', (c) => c.sortOrder ?? 0],
        ['Status', (c) => badge(c.isActive ? 'active' : 'hidden')],
        ['Actions', (c) => <RowActions onEdit={() => setForm(categoryToForm(c))} onDelete={() => removeDoc('categories', c.id, refresh, setToast)} />],
      ]} />
    </CrudPage>
  );
}

function Banners({ data, refresh, setToast }) {
  const [form, setForm] = useState(initialForms.banner);
  return (
    <CrudPage title="Banners" subtitle="Control homepage banner images, text, destination category, and order.">
      <EditorPanel title={form.id ? 'Edit banner' : 'Add banner'} onReset={() => setForm(initialForms.banner)} onSave={() => saveBanner(form, refresh, setToast, setForm)}>
        <FormGrid>
          <TextInput label="Title" value={form.title} onChange={(title) => setForm({ ...form, title })} />
          <TextInput label="Subtitle" value={form.subtitle} onChange={(subtitle) => setForm({ ...form, subtitle })} />
          <TextInput label="Action category" value={form.actionCategory} onChange={(actionCategory) => setForm({ ...form, actionCategory })} />
          <TextInput label="Sort order" type="number" value={form.sortOrder} onChange={(sortOrder) => setForm({ ...form, sortOrder })} />
          <TextInput label="Image URL" value={form.imageUrl} onChange={(imageUrl) => setForm({ ...form, imageUrl })} wide />
          <ImageUploader label="Upload banner image" folder={cloudinaryConfig.bannerFolder} onUploaded={(url) => setForm((current) => ({ ...current, imageUrl: url }))} />
          <Toggle label="Active" checked={form.isActive} onChange={(isActive) => setForm({ ...form, isActive })} />
        </FormGrid>
      </EditorPanel>
      <CardGrid>
        {data.banners.map((b) => (
          <RecordCard key={b.id} title={b.title || 'Banner'} image={b.imageUrl} meta={[b.subtitle || 'No subtitle', b.actionCategory || 'No action', b.isActive ? 'Active' : 'Hidden']}>
            <button onClick={() => setForm(bannerToForm(b))}>Edit</button>
            <button className="danger" onClick={() => removeDoc('banners', b.id, refresh, setToast)}>Delete</button>
          </RecordCard>
        ))}
      </CardGrid>
    </CrudPage>
  );
}

function Coupons({ data, refresh, setToast }) {
  const [form, setForm] = useState(initialForms.coupon);
  return (
    <CrudPage title="Coupons" subtitle="Create flat or percentage discounts with usage and expiry controls.">
      <EditorPanel title={form.id ? 'Edit coupon' : 'Add coupon'} onReset={() => setForm(initialForms.coupon)} onSave={() => saveCoupon(form, refresh, setToast, setForm)}>
        <FormGrid>
          <TextInput label="Code" value={form.code} onChange={(code) => setForm({ ...form, code: code.toUpperCase() })} />
          <SelectInput label="Type" value={form.discountType} onChange={(discountType) => setForm({ ...form, discountType })} options={['flatAmount', 'percentage']} />
          <TextInput label="Discount value" type="number" value={form.discountValue} onChange={(discountValue) => setForm({ ...form, discountValue })} />
          <TextInput label="Min cart" type="number" value={form.minCartValue} onChange={(minCartValue) => setForm({ ...form, minCartValue })} />
          <TextInput label="Usage limit" type="number" value={form.usageLimit} onChange={(usageLimit) => setForm({ ...form, usageLimit })} />
          <TextInput label="Expiry date" type="date" value={form.expiryDate} onChange={(expiryDate) => setForm({ ...form, expiryDate })} />
          <TextInput label="Category IDs" value={form.applicableCategoryIds} onChange={(applicableCategoryIds) => setForm({ ...form, applicableCategoryIds })} wide />
          <TextInput label="Product IDs" value={form.applicableProductIds} onChange={(applicableProductIds) => setForm({ ...form, applicableProductIds })} wide />
          <Toggle label="Active" checked={form.isActive} onChange={(isActive) => setForm({ ...form, isActive })} />
        </FormGrid>
      </EditorPanel>
      <DataTable rows={data.coupons} columns={[
        ['Code', (c) => <b>{c.code}</b>],
        ['Type', (c) => c.discountType],
        ['Value', (c) => c.discountValue],
        ['Used', (c) => `${c.usageCount || 0}/${c.usageLimit || 'unlimited'}`],
        ['Status', (c) => badge(c.isActive ? 'active' : 'hidden')],
        ['Actions', (c) => <RowActions onEdit={() => setForm(couponToForm(c))} onDelete={() => removeDoc('coupons', c.id, refresh, setToast)} />],
      ]} />
    </CrudPage>
  );
}

function StoreSettings({ data, refresh, setToast }) {
  const [delivery, setDelivery] = useState(data.deliverySettings);
  const [payment, setPayment] = useState(data.paymentSettings);
  useEffect(() => {
    setDelivery(data.deliverySettings);
    setPayment(data.paymentSettings);
  }, [data.deliverySettings, data.paymentSettings]);
  return (
    <CrudPage title="Store settings" subtitle="Delivery fee, free shipping threshold, support WhatsApp, and Razorpay runtime settings.">
      <div className="settings-grid">
        <EditorPanel title="Delivery settings" onSave={() => saveSettings('delivery_settings', delivery, refresh, setToast)}>
          <FormGrid>
            <TextInput label="Free delivery threshold" type="number" value={delivery.freeDeliveryThreshold ?? ''} onChange={(freeDeliveryThreshold) => setDelivery({ ...delivery, freeDeliveryThreshold: numberOrZero(freeDeliveryThreshold) })} />
            <TextInput label="Delivery fee" type="number" value={delivery.deliveryFee ?? ''} onChange={(deliveryFee) => setDelivery({ ...delivery, deliveryFee: numberOrZero(deliveryFee) })} />
            <TextInput label="Support WhatsApp" value={delivery.supportWhatsAppNumber ?? ''} onChange={(supportWhatsAppNumber) => setDelivery({ ...delivery, supportWhatsAppNumber })} wide />
          </FormGrid>
        </EditorPanel>
        <EditorPanel title="Payment settings" onSave={() => saveSettings('payment_settings', payment, refresh, setToast)}>
          <FormGrid>
            <TextInput label="Razorpay key ID" value={payment.keyId ?? ''} onChange={(keyId) => setPayment({ ...payment, keyId })} />
            <TextInput label="Backend base URL" value={payment.backendBaseUrl ?? ''} onChange={(backendBaseUrl) => setPayment({ ...payment, backendBaseUrl })} />
            <TextInput label="Currency" value={payment.currency ?? 'INR'} onChange={(currency) => setPayment({ ...payment, currency })} />
            <TextInput label="Merchant name" value={payment.merchantName ?? ''} onChange={(merchantName) => setPayment({ ...payment, merchantName })} />
            <TextInput label="Checkout description" value={payment.checkoutDescription ?? ''} onChange={(checkoutDescription) => setPayment({ ...payment, checkoutDescription })} wide />
            <Toggle label="Online payment enabled" checked={payment.isOnlinePaymentEnabled ?? true} onChange={(isOnlinePaymentEnabled) => setPayment({ ...payment, isOnlinePaymentEnabled })} />
          </FormGrid>
        </EditorPanel>
      </div>
    </CrudPage>
  );
}

function HomeSections({ data, refresh, setToast }) {
  const [form, setForm] = useState(initialForms.section);
  return (
    <CrudPage title="Home sections" subtitle="Curate homepage product rails, section discounts, and display windows.">
      <EditorPanel title={form.id ? 'Edit section' : 'Add section'} onReset={() => setForm(initialForms.section)} onSave={() => saveSection(form, refresh, setToast, setForm)}>
        <FormGrid>
          <TextInput label="Title" value={form.title} onChange={(title) => setForm({ ...form, title })} />
          <TextInput label="Sort order" type="number" value={form.sortOrder} onChange={(sortOrder) => setForm({ ...form, sortOrder })} />
          <TextInput label="Start date" type="date" value={form.startDate} onChange={(startDate) => setForm({ ...form, startDate })} />
          <TextInput label="End date" type="date" value={form.endDate} onChange={(endDate) => setForm({ ...form, endDate })} />
          <SelectInput label="Discount type" value={form.sectionDiscountType} onChange={(sectionDiscountType) => setForm({ ...form, sectionDiscountType })} options={['', 'flatAmount', 'percentage']} />
          <TextInput label="Discount value" type="number" value={form.sectionDiscountValue} onChange={(sectionDiscountValue) => setForm({ ...form, sectionDiscountValue })} />
          <TextInput label="Product IDs" value={form.productIds} onChange={(productIds) => setForm({ ...form, productIds })} wide />
          <Toggle label="Active" checked={form.isActive} onChange={(isActive) => setForm({ ...form, isActive })} />
        </FormGrid>
      </EditorPanel>
      <DataTable rows={data.sections} columns={[
        ['Title', (s) => <b>{s.title}</b>],
        ['Products', (s) => (s.productIds || []).length],
        ['Sort', (s) => s.sortOrder ?? 0],
        ['Status', (s) => badge(s.isActive ? 'active' : 'hidden')],
        ['Actions', (s) => <RowActions onEdit={() => setForm(sectionToForm(s))} onDelete={() => removeDoc('home_sections', s.id, refresh, setToast)} />],
      ]} />
    </CrudPage>
  );
}

function CrudPage({ title, subtitle, action, children }) {
  return (
    <section className="crud-page">
      <div className="section-head">
        <div>
          <p className="eyebrow">Workspace</p>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

function Panel({ title, subtitle, children }) {
  return <section className="panel"><h3>{title}</h3><p>{subtitle}</p>{children}</section>;
}

function Metric({ label, value, detail, icon: Icon, tone }) {
  return <section className={`metric ${tone}`}><Icon size={24} /><strong>{value}</strong><b>{label}</b><span>{detail}</span></section>;
}

function MiniStat({ label, value }) {
  return <div className="mini-stat"><b>{value}</b><span>{label}</span></div>;
}

function Donut({ total, open, delivered, cancelled }) {
  const cancelDeg = total ? (cancelled / total) * 360 : 0;
  const deliveredDeg = total ? (delivered / total) * 360 : 0;
  return (
    <div className="donut" style={{ '--cancel': `${cancelDeg}deg`, '--delivered': `${cancelDeg + deliveredDeg}deg` }}>
      <div><b>{total}</b><span>total orders</span></div>
    </div>
  );
}

function Legend({ label, value, tone }) {
  return <div className="legend"><i className={tone} /> <span>{label}</span><b>{value}</b></div>;
}

function EditorPanel({ title, children, onSave, onReset }) {
  return (
    <section className="editor-panel">
      <div className="editor-head"><h3>{title}</h3><div>{onReset ? <button onClick={onReset}>Reset</button> : null}<button className="primary-btn small" onClick={onSave}><Save size={16} /> Save</button></div></div>
      {children}
    </section>
  );
}

function FormGrid({ children }) { return <div className="form-grid">{children}</div>; }

function TextInput({ label, value, onChange, type = 'text', wide }) {
  return <label className={wide ? 'wide' : ''}><span>{label}</span><input type={type} value={value ?? ''} onChange={(e) => onChange(e.target.value)} /></label>;
}

function TextArea({ label, value, onChange }) {
  return <label className="wide"><span>{label}</span><textarea value={value ?? ''} onChange={(e) => onChange(e.target.value)} /></label>;
}

function SelectInput({ label, value, onChange, options }) {
  return <label><span>{label}</span><select value={value ?? ''} onChange={(e) => onChange(e.target.value)}>{options.map((option) => <option key={option} value={option}>{option || 'None'}</option>)}</select></label>;
}

function Toggle({ label, checked, onChange }) {
  return <label className="toggle"><input type="checkbox" checked={!!checked} onChange={(e) => onChange(e.target.checked)} /><span>{label}</span></label>;
}

function ImageUploader({ label, folder, onUploaded }) {
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  async function upload(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError('');
    try {
      const url = await uploadToCloudinary(file, folder);
      onUploaded(url);
    } catch (err) {
      setError(err.message || 'Upload failed.');
    } finally {
      setUploading(false);
      event.target.value = '';
    }
  }
  return (
    <label className="wide upload-field">
      <span>{label}</span>
      <input type="file" accept="image/*" disabled={uploading} onChange={upload} />
      <small>{uploading ? 'Uploading to Cloudinary...' : 'Select an image to upload and auto-fill the URL.'}</small>
      {error ? <small className="field-error">{error}</small> : null}
    </label>
  );
}

function DataTable({ rows, columns, empty = 'No records yet.' }) {
  if (!rows.length) return <div className="empty-state">{empty}</div>;
  return <div className="table-wrap"><table><thead><tr>{columns.map(([name]) => <th key={name}>{name}</th>)}</tr></thead><tbody>{rows.map((row) => <tr key={row.id}>{columns.map(([name, render]) => <td key={name}>{render(row)}</td>)}</tr>)}</tbody></table></div>;
}

function CompactTable({ rows, columns }) {
  if (!rows.length) return <div className="empty-state compact">No recent orders.</div>;
  return <DataTable rows={rows} columns={columns} />;
}

function CardGrid({ children }) { return <div className="card-grid">{children}</div>; }

function RecordCard({ title, image, meta, children }) {
  return <article className="record-card">{image ? <img src={image} alt="" /> : <div className="image-placeholder"><Image size={28} /></div>}<div><h3>{title}</h3>{meta.map((m) => <p key={m}>{m}</p>)}</div><footer>{children}</footer></article>;
}

function RowActions({ onEdit, onDelete }) {
  return <div className="row-actions"><button onClick={onEdit}>Edit</button><button className="danger" onClick={onDelete}><Trash2 size={15} /> Delete</button></div>;
}

function Alert({ message, onClose }) {
  return <div className="alert"><span>{message}</span>{onClose ? <button onClick={onClose}><X size={16} /></button> : null}</div>;
}

function Toast({ message, onClose }) {
  useEffect(() => {
    const timer = setTimeout(onClose, 5000);
    return () => clearTimeout(timer);
  }, [onClose]);
  return <div className="toast"><CheckCircle2 size={18} /> {message}</div>;
}

function LoadingScreen({ message }) { return <div className="loading-screen"><Loader2 className="spin" /><p>{message}</p></div>; }
function LoadingPanel() { return <div className="loading-panel"><Loader2 className="spin" /> Loading admin data...</div>; }

async function loadAllData(setData, setLoading, setToast) {
  setLoading(true);
  try {
    const [products, categories, orders, banners, coupons, sections, delivery, payment] = await Promise.all([
      readCollection('products', 'name'),
      readCollection('categories', 'sortOrder'),
      readCollection('orders', 'createdAt', true),
      readCollection('banners', 'sortOrder'),
      readCollection('coupons', 'code'),
      readCollection('home_sections', 'sortOrder'),
      readDoc('store_config', 'delivery_settings', { freeDeliveryThreshold: 999, deliveryFee: 49, supportWhatsAppNumber: '' }),
      readDoc('store_config', 'payment_settings', { isOnlinePaymentEnabled: true, keyId: '', backendBaseUrl: '', currency: 'INR', merchantName: 'Store Checkout', checkoutDescription: 'Order payment' }),
    ]);
    setData({ products, categories, orders, banners, coupons, sections, deliverySettings: delivery, paymentSettings: payment });
  } catch (error) {
    setToast(error.message || 'Unable to load admin data.');
  } finally {
    setLoading(false);
  }
}

async function readCollection(name, sortField, desc = false) {
  try {
    const snapshot = await getDocs(query(collection(db, name), orderBy(sortField, desc ? 'desc' : 'asc')));
    return snapshot.docs.map((item) => ({ id: item.id, ...item.data() }));
  } catch (_) {
    const snapshot = await getDocs(collection(db, name));
    return snapshot.docs.map((item) => ({ id: item.id, ...item.data() }));
  }
}

async function readDoc(collectionName, id, fallback) {
  const snapshot = await getDoc(doc(db, collectionName, id));
  return snapshot.exists() ? snapshot.data() : fallback;
}

function emptyData() {
  return { products: [], categories: [], orders: [], banners: [], coupons: [], sections: [], deliverySettings: {}, paymentSettings: {} };
}

function buildStats(data) {
  const delivered = data.orders.filter((o) => (o.orderStatus || o.status) === 'delivered');
  const cancelled = data.orders.filter((o) => (o.orderStatus || o.status) === 'cancelled');
  const open = data.orders.filter((o) => !['delivered', 'cancelled'].includes(o.orderStatus || o.status));
  const deliveredRevenue = delivered.reduce((sum, o) => sum + orderTotal(o), 0);
  return {
    deliveredOrders: delivered.length,
    cancelledOrders: cancelled.length,
    openOrders: open.length,
    deliveredRevenue,
    openValue: open.reduce((sum, o) => sum + orderTotal(o), 0),
    averageDeliveredOrder: delivered.length ? deliveredRevenue / delivered.length : 0,
    activeProducts: data.products.filter((p) => p.isActive !== false).length,
    featuredProducts: data.products.filter((p) => p.isFeatured).length,
    activeBanners: data.banners.filter((b) => b.isActive !== false).length,
  };
}

async function saveProduct(form, refresh, setToast, setForm) {
  const packOptions = parsePackOptions(form.packOptions, form.price, form.salePrice, form.stockQuantity);
  const defaultPack = packOptions.find((item) => item.isDefault) || packOptions[0];
  const payload = {
    name: form.name.trim(),
    brandName: form.brandName.trim(),
    category: form.category.trim(),
    description: form.description.trim(),
    price: defaultPack.price,
    salePrice: defaultPack.salePrice,
    discountPercent: discountPercent(defaultPack.price, defaultPack.salePrice),
    imageUrl: form.imageUrl.trim(),
    imageUrls: csv(form.imageUrls || form.imageUrl),
    stockQuantity: defaultPack.stockQuantity,
    packOptions,
    isActive: form.isActive,
    isFeatured: form.isFeatured,
    isPopular: form.isPopular,
    isNewArrival: form.isNewArrival,
    updatedAt: serverTimestamp(),
  };
  await saveCollectionDoc('products', form.id, payload);
  setForm(initialForms.product);
  setToast('Product saved.');
  refresh();
}

async function saveCategory(form, refresh, setToast, setForm) {
  await saveCollectionDoc('categories', form.id, {
    title: form.title.trim(),
    parentId: form.parentId.trim() || null,
    image: form.image.trim(),
    svgSrc: form.svgSrc.trim(),
    sortOrder: intOrZero(form.sortOrder),
    isActive: form.isActive,
  });
  setForm(initialForms.category);
  setToast('Category saved.');
  refresh();
}

async function saveBanner(form, refresh, setToast, setForm) {
  await saveCollectionDoc('banners', form.id, { ...form, sortOrder: intOrZero(form.sortOrder), updatedAt: serverTimestamp() });
  setForm(initialForms.banner);
  setToast('Banner saved.');
  refresh();
}

async function saveCoupon(form, refresh, setToast, setForm) {
  await saveCollectionDoc('coupons', form.id, {
    code: form.code.trim().toUpperCase(),
    discountType: form.discountType,
    discountValue: numberOrZero(form.discountValue),
    minCartValue: numberOrZero(form.minCartValue),
    expiryDate: form.expiryDate ? new Date(form.expiryDate) : null,
    usageLimit: form.usageLimit === '' ? null : intOrZero(form.usageLimit),
    usageCount: intOrZero(form.usageCount),
    applicableCategoryIds: csv(form.applicableCategoryIds),
    applicableProductIds: csv(form.applicableProductIds),
    isActive: form.isActive,
    updatedAt: serverTimestamp(),
  });
  setForm(initialForms.coupon);
  setToast('Coupon saved.');
  refresh();
}

async function saveSection(form, refresh, setToast, setForm) {
  await saveCollectionDoc('home_sections', form.id, {
    title: form.title.trim(),
    productIds: csv(form.productIds),
    sortOrder: intOrZero(form.sortOrder),
    startDate: form.startDate ? new Date(form.startDate) : null,
    endDate: form.endDate ? new Date(form.endDate) : null,
    sectionDiscountType: form.sectionDiscountType || null,
    sectionDiscountValue: form.sectionDiscountValue === '' ? null : numberOrZero(form.sectionDiscountValue),
    isActive: form.isActive,
    updatedAt: serverTimestamp(),
  });
  setForm(initialForms.section);
  setToast('Home section saved.');
  refresh();
}

async function saveSettings(id, payload, refresh, setToast) {
  await setDoc(doc(db, 'store_config', id), payload, { merge: true });
  setToast('Settings saved.');
  refresh();
}

async function saveCollectionDoc(name, id, payload) {
  if (id) await setDoc(doc(db, name, id), payload, { merge: true });
  else await addDoc(collection(db, name), { ...payload, createdAt: serverTimestamp() });
}

async function removeDoc(name, id, refresh, setToast) {
  if (!confirm('Delete this record?')) return;
  await deleteDoc(doc(db, name, id));
  setToast('Record deleted.');
  refresh();
}

async function updateOrderStatus(id, status, refresh, setToast) {
  await updateDoc(doc(db, 'orders', id), { orderStatus: status, status, updatedAt: serverTimestamp() });
  setToast('Order status updated.');
  refresh();
}

function productToForm(p) { return { ...initialForms.product, ...p, imageUrls: (p.imageUrls || []).join(', '), packOptions: packOptionsToText(p.packOptions, p) }; }
function categoryToForm(c) { return { ...initialForms.category, ...c, sortOrder: c.sortOrder ?? '' }; }
function bannerToForm(b) { return { ...initialForms.banner, ...b, sortOrder: b.sortOrder ?? '' }; }
function couponToForm(c) { return { ...initialForms.coupon, ...c, expiryDate: toDateInput(c.expiryDate), applicableCategoryIds: (c.applicableCategoryIds || []).join(', '), applicableProductIds: (c.applicableProductIds || []).join(', ') }; }
function sectionToForm(s) { return { ...initialForms.section, ...s, startDate: toDateInput(s.startDate), endDate: toDateInput(s.endDate), productIds: (s.productIds || []).join(', ') }; }

function toDateInput(value) {
  const date = value?.toDate ? value.toDate() : value ? new Date(value) : null;
  return date && !Number.isNaN(date.valueOf()) ? date.toISOString().slice(0, 10) : '';
}

function csv(value) { return String(value || '').split(',').map((item) => item.trim()).filter(Boolean); }
function numberOrZero(value) { return Number(value || 0); }
function intOrZero(value) { return parseInt(value || 0, 10); }
function money(value) { return `Rs ${Number(value || 0).toFixed(0)}`; }
function orderTotal(order) { return Number(order.totalPrice ?? order.total ?? order.pricing?.totalAmount ?? 0); }
function badge(text) { return <span className={`badge ${text}`}>{text}</span>; }

function topCategories(products) {
  const counts = new Map();
  products.forEach((p) => counts.set(p.category || 'Unassigned', (counts.get(p.category || 'Unassigned') || 0) + 1));
  return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6).map(([name, count]) => ({ name, count }));
}

async function uploadToCloudinary(file, folder) {
  if (!cloudinaryConfig.cloudName || !cloudinaryConfig.unsignedUploadPreset) {
    throw new Error('Cloudinary is not configured.');
  }
  const body = new FormData();
  body.append('file', file);
  body.append('upload_preset', cloudinaryConfig.unsignedUploadPreset);
  body.append('folder', folder);
  body.append('quality', 'auto:good');
  body.append('fetch_format', 'auto');
  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudinaryConfig.cloudName}/image/upload`, {
    method: 'POST',
    body,
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || 'Cloudinary upload failed.');
  }
  return data.secure_url || '';
}

function parsePackOptions(text, fallbackPrice, fallbackSalePrice, fallbackStock) {
  const lines = String(text || '').split('\n').map((line) => line.trim()).filter(Boolean);
  const parsed = lines.map((line, index) => {
    const [rawLabel, rawPrice, rawSale, rawStock, rawDefault] = line.split('|').map((part) => (part || '').trim());
    const label = rawLabel || (index === 0 ? 'Standard' : `Pack ${index + 1}`);
    const price = numberOrZero(rawPrice || fallbackPrice);
    const salePrice = rawSale === '' ? null : numberOrZero(rawSale || fallbackSalePrice);
    return {
      id: slugify(label),
      label,
      price,
      salePrice,
      stockQuantity: intOrZero(rawStock || fallbackStock),
      isDefault: rawDefault === 'default' || index === 0,
    };
  });
  if (parsed.length) {
    return parsed.map((item, index) => ({ ...item, isDefault: index === 0 ? true : !!item.isDefault && !parsed.slice(0, index).some((p) => p.isDefault) }));
  }
  return [{
    id: 'standard',
    label: 'Standard',
    price: numberOrZero(fallbackPrice),
    salePrice: fallbackSalePrice === '' ? null : numberOrZero(fallbackSalePrice),
    stockQuantity: intOrZero(fallbackStock),
    isDefault: true,
  }];
}

function packOptionsToText(packOptions, product) {
  const packs = Array.isArray(packOptions) && packOptions.length ? packOptions : [{
    label: 'Standard',
    price: product.price || 0,
    salePrice: product.salePrice ?? '',
    stockQuantity: product.stockQuantity || 0,
    isDefault: true,
  }];
  return packs.map((pack) => [
    pack.label || pack.id || 'Standard',
    pack.price ?? 0,
    pack.salePrice ?? '',
    pack.stockQuantity ?? 0,
    pack.isDefault ? 'default' : '',
  ].join('|')).join('\n');
}

function discountPercent(price, salePrice) {
  if (!salePrice || !price || salePrice >= price) return 0;
  return Math.round(((price - salePrice) / price) * 100);
}

function slugify(value) {
  return String(value || '').trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'standard';
}

function formatDate(value) {
  const date = value?.toDate ? value.toDate() : value ? new Date(value) : null;
  if (!date || Number.isNaN(date.valueOf())) return 'Created recently';
  return new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
}

function totalItems(order) {
  return (order.items || []).reduce((sum, item) => sum + Number(item.quantity || 0), 0);
}

function orderItemName(item) {
  const name = item.productName || item.name || 'Product';
  return item.selectedOptionLabel ? `${name} (${item.selectedOptionLabel})` : name;
}

function itemLineTotal(item) {
  return Number(item.lineTotal ?? (Number(item.productPrice ?? item.unitPrice ?? 0) * Number(item.quantity || 0)));
}

function downloadInvoice(order, setToast) {
  const items = Array.isArray(order.items) ? order.items : [];
  const address = order.deliveryAddress || {};
  const pricing = order.pricing || {};
  const payment = order.payment || {};
  const html = `<!doctype html><html><head><title>Invoice ${order.orderId || order.id}</title><style>body{font-family:Arial,sans-serif;padding:32px;color:#111}h1{margin:0}.muted{color:#666}.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin:24px 0}table{width:100%;border-collapse:collapse}th,td{padding:10px;border-bottom:1px solid #ddd;text-align:left}.total{font-size:20px;font-weight:700}</style></head><body><h1>PetsWorld Invoice</h1><p class="muted">Order #${escapeHtml(order.orderId || order.id)} · ${escapeHtml(formatDate(order.createdAt))}</p><div class="grid"><section><h3>Customer</h3><p>${escapeHtml(order.userName || order.customerName || address.fullName || '')}<br>${escapeHtml(order.userEmail || '')}<br>${escapeHtml(order.userPhone || order.phoneNumber || address.phone || '')}</p></section><section><h3>Delivery</h3><p>${escapeHtml([address.addressLine1, address.addressLine2, address.city, address.state, address.pincode].filter(Boolean).join(', ') || order.address || '')}</p></section></div><table><thead><tr><th>Item</th><th>Qty</th><th>Unit</th><th>Total</th></tr></thead><tbody>${items.map((item) => `<tr><td>${escapeHtml(orderItemName(item))}<br><span class="muted">${escapeHtml(item.productId || '')}</span></td><td>${item.quantity || 0}</td><td>${money(item.productPrice ?? item.unitPrice)}</td><td>${money(itemLineTotal(item))}</td></tr>`).join('')}</tbody></table><div class="grid"><section><h3>Payment</h3><p>Method: ${escapeHtml(payment.paymentMethod || order.paymentMethod || 'cod')}<br>Status: ${escapeHtml(payment.paymentStatus || order.paymentStatus || 'pending')}<br>Razorpay Payment ID: ${escapeHtml(payment.razorpayPaymentId || '-')}</p></section><section><h3>Totals</h3><p>Subtotal: ${money(pricing.subtotal ?? order.subtotal)}<br>Product discount: ${money(pricing.productDiscount)}<br>Coupon: ${escapeHtml(pricing.couponCode || '-')}<br>Coupon discount: ${money(pricing.couponDiscount)}<br>Delivery: ${money(pricing.deliveryCharge ?? order.deliveryCharge)}</p><p class="total">Total: ${money(orderTotal(order))}</p></section></div><script>window.print()</script></body></html>`;
  const win = window.open('', '_blank', 'noopener,noreferrer');
  if (!win) {
    setToast('Allow popups to generate invoice.');
    return;
  }
  win.document.write(html);
  win.document.close();
  setToast('Invoice opened.');
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

function exportOrdersCsv(orders, setToast) {
  const header = ['Order ID', 'Customer', 'Phone', 'Status', 'Payment', 'Total'];
  const rows = orders.map((o) => [o.id, o.customerName || o.userName || '', o.phoneNumber || o.userPhone || '', o.orderStatus || o.status || '', o.payment?.paymentStatus || o.paymentStatus || '', orderTotal(o)]);
  const csvText = [header, ...rows].map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(',')).join('\n');
  const url = URL.createObjectURL(new Blob([csvText], { type: 'text/csv;charset=utf-8;' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = `petsworld-orders-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
  setToast('Orders exported.');
}

function mapAuthError(error) {
  if (error.code === 'auth/invalid-credential') return 'Email or password is incorrect.';
  if (error.code === 'auth/user-not-found') return 'No account found for this email.';
  if (error.code === 'auth/too-many-requests') return 'Too many attempts. Try again later.';
  return error.message || 'Sign in failed.';
}

createRoot(document.getElementById('root')).render(<App />);
