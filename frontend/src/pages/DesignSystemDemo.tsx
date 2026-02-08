import React, { useState } from 'react';
import {
  Button,
  Input,
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
  Modal,
  ModalFooter,
  Badge,
  Avatar,
  Spinner,
  ToastContainer,
  type ToastProps,
} from '../components/ui';
import { DeviceCard, type DeviceInfo } from '../components/DeviceCard';
import { CommandPanel } from '../components/CommandPanel';
import { StatCard } from '../components/StatCard';

export const DesignSystemDemo: React.FC = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [toasts, setToasts] = useState<ToastProps[]>([]);

  const addToast = (type: ToastProps['type'], message: string) => {
    const id = Date.now().toString();
    setToasts((prev) => [...prev, { id, type, message, onClose: removeToast }]);
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const mockDevice: DeviceInfo = {
    id: '1',
    name: 'Galaxy S21',
    model: 'Samsung Galaxy S21',
    os: 'Android 13',
    status: 'online',
    lastSeen: '2 mins ago',
    batteryLevel: 85,
    location: 'New York, USA',
  };

  return (
    <div className="min-h-screen p-8 space-y-12 custom-scrollbar">
      {/* Header */}
      <div className="text-center mb-12">
        <h1 className="text-5xl font-bold text-gradient mb-4">
          Design System Demo
        </h1>
        <p className="text-white/60 text-lg">
          Next-Gen UI Components with Tailwind CSS
        </p>
      </div>

      {/* Stats Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Stat Cards</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <StatCard
            title="Total Devices"
            value={42}
            change={{ value: 12, type: 'increase' }}
            variant="electric"
            icon={
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
              </svg>
            }
          />
          <StatCard
            title="Active Sessions"
            value={18}
            change={{ value: 5, type: 'increase' }}
            variant="cyber"
            icon={
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                <path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z" />
              </svg>
            }
          />
          <StatCard
            title="Commands Executed"
            value="1.2K"
            change={{ value: 8, type: 'increase' }}
            variant="neon"
            icon={
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M2 5a2 2 0 012-2h12a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm3.293 1.293a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 01-1.414-1.414L7.586 10 5.293 7.707a1 1 0 010-1.414zM11 12a1 1 0 100 2h3a1 1 0 100-2h-3z" clipRule="evenodd" />
              </svg>
            }
          />
          <StatCard
            title="Data Collected"
            value="523MB"
            change={{ value: 3, type: 'decrease' }}
            variant="default"
            icon={
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                <path d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3c0 1.657-3.134 3-7 3s-7-1.343-7-3z" />
                <path d="M3 7v3c0 1.657 3.134 3 7 3s7-1.343 7-3V7c0 1.657-3.134 3-7 3S3 8.657 3 7z" />
                <path d="M17 5c0 1.657-3.134 3-7 3S3 6.657 3 5s3.134-3 7-3 7 1.343 7 3z" />
              </svg>
            }
          />
        </div>
      </section>

      {/* Buttons Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Buttons</h2>
        <div className="flex flex-wrap gap-4">
          <Button variant="primary">Primary Button</Button>
          <Button variant="secondary">Secondary Button</Button>
          <Button variant="ghost">Ghost Button</Button>
          <Button variant="danger">Danger Button</Button>
          <Button variant="primary" isLoading>
            Loading...
          </Button>
          <Button
            variant="primary"
            icon={
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                <path fillRule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clipRule="evenodd" />
              </svg>
            }
          >
            With Icon
          </Button>
        </div>
      </section>

      {/* Inputs Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Inputs</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl">
          <Input label="Device Name" placeholder="Enter device name..." />
          <Input
            label="Email"
            type="email"
            placeholder="email@example.com"
            helperText="We'll never share your email"
          />
          <Input
            label="Password"
            type="password"
            error="Password must be at least 8 characters"
          />
          <Input
            label="Search"
            placeholder="Search devices..."
            icon={
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
              </svg>
            }
          />
        </div>
      </section>

      {/* Badges Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Badges</h2>
        <div className="flex flex-wrap gap-4">
          <Badge variant="success" dot>
            Online
          </Badge>
          <Badge variant="warning">Idle</Badge>
          <Badge variant="danger">Offline</Badge>
          <Badge variant="info">Processing</Badge>
          <Badge variant="default">Default</Badge>
        </div>
      </section>

      {/* Avatars Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Avatars</h2>
        <div className="flex flex-wrap gap-6 items-end">
          <Avatar size="sm" fallback="SM" status="online" />
          <Avatar size="md" fallback="MD" status="away" />
          <Avatar size="lg" fallback="LG" status="busy" />
          <Avatar size="xl" fallback="XL" status="offline" />
        </div>
      </section>

      {/* Spinners Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Spinners</h2>
        <div className="flex flex-wrap gap-8 items-end">
          <Spinner size="sm" variant="electric" />
          <Spinner size="md" variant="cyber" />
          <Spinner size="lg" variant="neon" />
          <Spinner size="xl" variant="electric" />
        </div>
      </section>

      {/* Cards Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Cards</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <Card variant="default">
            <CardHeader>
              <CardTitle>Default Card</CardTitle>
            </CardHeader>
            <CardContent>
              This is a default card with standard styling.
            </CardContent>
          </Card>

          <Card variant="glass">
            <CardHeader>
              <CardTitle>Glass Card</CardTitle>
            </CardHeader>
            <CardContent>
              This card has a glass-morphism effect.
            </CardContent>
          </Card>

          <Card variant="gradient">
            <CardHeader>
              <CardTitle>Gradient Card</CardTitle>
            </CardHeader>
            <CardContent>This card has a gradient background.</CardContent>
            <CardFooter>
              <Button variant="ghost" size="sm">
                Action
              </Button>
            </CardFooter>
          </Card>
        </div>
      </section>

      {/* Device Card Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Device Card</h2>
        <div className="max-w-md">
          <DeviceCard
            device={mockDevice}
            onClick={(device) => console.log('Clicked device:', device)}
            onAction={(action, device) => console.log('Action:', action, device)}
          />
        </div>
      </section>

      {/* Command Panel Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Command Panel</h2>
        <div className="max-w-2xl">
          <CommandPanel
            deviceId={mockDevice.id}
            onExecute={async (cmd) => {
              console.log('Executing:', cmd);
              await new Promise((resolve) => setTimeout(resolve, 1000));
            }}
            commandHistory={['get_location', 'take_photo', 'list_contacts']}
          />
        </div>
      </section>

      {/* Modal Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Modal</h2>
        <Button onClick={() => setIsModalOpen(true)}>Open Modal</Button>
        <Modal
          isOpen={isModalOpen}
          onClose={() => setIsModalOpen(false)}
          title="Example Modal"
          size="md"
        >
          <p className="text-white/80 mb-4">
            This is an example modal with glass-morphism styling.
          </p>
          <Input label="Name" placeholder="Enter your name..." />
          <ModalFooter>
            <Button variant="ghost" onClick={() => setIsModalOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => setIsModalOpen(false)}>Confirm</Button>
          </ModalFooter>
        </Modal>
      </section>

      {/* Toast Section */}
      <section>
        <h2 className="text-3xl font-semibold text-white mb-6">Toasts</h2>
        <div className="flex flex-wrap gap-4">
          <Button onClick={() => addToast('success', 'Operation completed successfully!')}>
            Success Toast
          </Button>
          <Button variant="secondary" onClick={() => addToast('info', 'Here is some information.')}>
            Info Toast
          </Button>
          <Button variant="ghost" onClick={() => addToast('warning', 'This is a warning message.')}>
            Warning Toast
          </Button>
          <Button variant="danger" onClick={() => addToast('error', 'An error occurred!')}>
            Error Toast
          </Button>
        </div>
      </section>

      {/* Toast Container */}
      <ToastContainer toasts={toasts} onClose={removeToast} />
    </div>
  );
};
