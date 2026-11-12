import AuthFailure from './components/AuthFailure';
import CompanyChat from './pages/CompanyChat';
import AssistantPage from './pages/AssistantPage';
import CalendarPage from './pages/CalendarPage';
import {OperationsCenter,SalesCenter,FinanceCenter,AuditCenter,PeopleCenter} from './pages/BusinessCenters';
import ModulesHub from './pages/ModulesHub';
import LeadsPage from './pages/domains/LeadsPage';
import OpportunitiesPage from './pages/domains/OpportunitiesPage';
import SuppliersPage from './pages/domains/SuppliersPage';
import PurchaseOrdersPage from './pages/domains/PurchaseOrdersPage';
import TeamShiftsPage from './pages/domains/TeamShiftsPage';
import TrainingRecordsPage from './pages/domains/TrainingRecordsPage';
import InspectionsPage from './pages/domains/InspectionsPage';
import NonconformitiesPage from './pages/domains/NonconformitiesPage';
import SupportTicketsPage from './pages/domains/SupportTicketsPage';
import ServiceRequestsPage from './pages/domains/ServiceRequestsPage';
import VehiclesPage from './pages/domains/VehiclesPage';
import RouteStopsPage from './pages/domains/RouteStopsPage';
import ProjectsPage from './pages/domains/ProjectsPage';
import ProjectMilestonesPage from './pages/domains/ProjectMilestonesPage';
import CustomerFeedbackPage from './pages/domains/CustomerFeedbackPage';
import FollowUpsPage from './pages/domains/FollowUpsPage';
import CostCentersPage from './pages/domains/CostCentersPage';
import FinancialGoalsPage from './pages/domains/FinancialGoalsPage';
import CampaignsPage from './pages/domains/CampaignsPage';
import ReferralPartnersPage from './pages/domains/ReferralPartnersPage';
import ProceduresPage from './pages/domains/ProceduresPage';
import RiskRegisterPage from './pages/domains/RiskRegisterPage';
import CustomerSegmentsPage from './pages/domains/CustomerSegmentsPage';
import LoyaltyRewardsPage from './pages/domains/LoyaltyRewardsPage';
import { Navigate,Route,Routes } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext';
import Layout from './components/Layout';
import {Loading} from './components/UI';
import Dashboard from './pages/Dashboard';
import WorkerHome from './pages/WorkerHome';
import ModulePage from './pages/ModulePage';
import DetailPage from './pages/DetailPage';
import {AuthPage,SetupPage,AcceptInvite,NewPassword} from './pages/AuthPages';
import {TeamPage,ReportsPage,SettingsPage,NotificationsPage,CustomerPortal} from './pages/Extras';
function Guard({children}:{children:React.ReactNode}){const {user,loading,organization}=useAuth();if(loading)return <Loading/>;if(!user)return <Navigate to="/login" replace/>;if(!organization)return <Navigate to="/setup" replace/>;return children}
function RoleHome(){const {role}=useAuth();return role==='TECHNICIAN'?<WorkerHome/>:<Dashboard/>}
function Entry(){const {user,loading,organization}=useAuth();if(loading)return <Loading/>;if(!user)return <Navigate to="/login" replace/>;if(!organization)return <Navigate to="/setup" replace/>;return <Navigate to="/app" replace/>}
export default function App(){const {authError,loading}=useAuth();if(authError&&!loading)return <AuthFailure/>;return <Routes><Route path="/" element={<Entry/>}/><Route path="/login" element={<AuthPage mode="login"/>}/><Route path="/cadastro" element={<AuthPage mode="register"/>}/><Route path="/recuperar" element={<AuthPage mode="reset"/>}/><Route path="/nova-senha" element={<NewPassword/>}/><Route path="/convite" element={<AcceptInvite/>}/><Route path="/setup" element={<SetupPage/>}/><Route path="/portal" element={<CustomerPortal/>}/><Route path="/app" element={<Guard><Layout/></Guard>}><Route index element={<RoleHome/>}/><Route path="detalhes/:table/:id" element={<DetailPage/>}/><Route path="conversas" element={<CompanyChat/>}/><Route path="assistente" element={<AssistantPage/>}/><Route path="equipe" element={<TeamPage/>}/><Route path="central-operacional" element={<OperationsCenter/>}/><Route path="central-comercial" element={<SalesCenter/>}/><Route path="central-financeira" element={<FinanceCenter/>}/><Route path="gestao-pessoas" element={<PeopleCenter/>}/><Route path="auditoria" element={<AuditCenter/>}/><Route path="modulos" element={<ModulesHub/>}/><Route path="relatorios" element={<ReportsPage/>}/><Route path="configuracoes" element={<SettingsPage/>}/><Route path="notificacoes" element={<NotificationsPage/>}/><Route path="leads" element={<LeadsPage/>}/><Route path="opportunities" element={<OpportunitiesPage/>}/><Route path="suppliers" element={<SuppliersPage/>}/><Route path="purchase-orders" element={<PurchaseOrdersPage/>}/><Route path="team-shifts" element={<TeamShiftsPage/>}/><Route path="training-records" element={<TrainingRecordsPage/>}/><Route path="inspections" element={<InspectionsPage/>}/><Route path="nonconformities" element={<NonconformitiesPage/>}/><Route path="support-tickets" element={<SupportTicketsPage/>}/><Route path="service-requests" element={<ServiceRequestsPage/>}/><Route path="vehicles" element={<VehiclesPage/>}/><Route path="route-stops" element={<RouteStopsPage/>}/><Route path="projects" element={<ProjectsPage/>}/><Route path="project-milestones" element={<ProjectMilestonesPage/>}/><Route path="customer-feedback" element={<CustomerFeedbackPage/>}/><Route path="follow-ups" element={<FollowUpsPage/>}/><Route path="cost-centers" element={<CostCentersPage/>}/><Route path="financial-goals" element={<FinancialGoalsPage/>}/><Route path="campaigns" element={<CampaignsPage/>}/><Route path="referral-partners" element={<ReferralPartnersPage/>}/><Route path="procedures" element={<ProceduresPage/>}/><Route path="risk-register" element={<RiskRegisterPage/>}/><Route path="customer-segments" element={<CustomerSegmentsPage/>}/><Route path="loyalty-rewards" element={<LoyaltyRewardsPage/>}/><Route path="agenda" element={<CalendarPage/>}/><Route path=":module" element={<ModulePage/>}/></Route><Route path="*" element={<Navigate to="/" replace/>}/></Routes>}
