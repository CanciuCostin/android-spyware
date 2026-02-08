import { useState } from 'react';
import { 
  FadeIn, 
  SlideIn, 
  ScaleIn, 
  SkeletonLoader, 
  PulseLoader, 
  ProgressBar,
  AnimatedButton,
  AnimatedCard,
  ParticleBackground,
} from '../components/animations';
import { Card, CardHeader, CardTitle, CardContent } from '../components/ui';

export function AnimationsDemo() {
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(45);
  const [showSkeleton, setShowSkeleton] = useState(true);

  const handleLoadingDemo = () => {
    setLoading(true);
    setTimeout(() => setLoading(false), 3000);
  };

  const handleSkeletonDemo = () => {
    setShowSkeleton(true);
    setTimeout(() => setShowSkeleton(false), 2000);
  };

  return (
    <div className="relative min-h-screen p-8">
      {/* Particle Background Demo */}
      <ParticleBackground effect="cyber" density="low" />

      <div className="relative z-10 space-y-8 max-w-7xl mx-auto">
        {/* Header */}
        <FadeIn>
          <div className="text-center mb-12">
            <h1 className="text-4xl font-bold text-white mb-4">
              Framer Motion Animations Demo
            </h1>
            <p className="text-white/60">
              Comprehensive showcase of all animation components
            </p>
          </div>
        </FadeIn>

        {/* Entry Animations */}
        <SlideIn direction="bottom">
          <Card variant="glass">
            <CardHeader>
              <CardTitle>Entry Animations</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <FadeIn delay={0.1}>
                  <div className="p-4 bg-blue-500/10 rounded-lg border border-blue-500/30">
                    <h3 className="font-semibold mb-2">FadeIn</h3>
                    <p className="text-sm text-white/60">Simple fade in animation</p>
                  </div>
                </FadeIn>

                <SlideIn direction="left" delay={0.2}>
                  <div className="p-4 bg-green-500/10 rounded-lg border border-green-500/30">
                    <h3 className="font-semibold mb-2">SlideIn</h3>
                    <p className="text-sm text-white/60">Slide from any direction</p>
                  </div>
                </SlideIn>

                <ScaleIn delay={0.3} bounce>
                  <div className="p-4 bg-purple-500/10 rounded-lg border border-purple-500/30">
                    <h3 className="font-semibold mb-2">ScaleIn</h3>
                    <p className="text-sm text-white/60">Scale with bounce effect</p>
                  </div>
                </ScaleIn>
              </div>
            </CardContent>
          </Card>
        </SlideIn>

        {/* Loading States */}
        <FadeIn delay={0.2}>
          <Card variant="glass">
            <CardHeader>
              <CardTitle>Loading States</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {/* Skeleton Loaders */}
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="font-semibold">Skeleton Loaders</h3>
                    <AnimatedButton size="sm" onClick={handleSkeletonDemo}>
                      Toggle
                    </AnimatedButton>
                  </div>
                  {showSkeleton ? (
                    <div className="space-y-3">
                      <SkeletonLoader type="card" />
                      <SkeletonLoader type="list" count={3} />
                    </div>
                  ) : (
                    <div className="p-4 bg-green-500/10 rounded-lg text-center">
                      Content Loaded!
                    </div>
                  )}
                </div>

                {/* Pulse Loader */}
                <div>
                  <h3 className="font-semibold mb-4">Pulse Loaders</h3>
                  <div className="flex gap-6 items-center">
                    <div>
                      <p className="text-sm text-white/60 mb-2">Small</p>
                      <PulseLoader size="sm" />
                    </div>
                    <div>
                      <p className="text-sm text-white/60 mb-2">Medium</p>
                      <PulseLoader size="md" />
                    </div>
                    <div>
                      <p className="text-sm text-white/60 mb-2">Large</p>
                      <PulseLoader size="lg" />
                    </div>
                  </div>
                </div>

                {/* Progress Bars */}
                <div>
                  <h3 className="font-semibold mb-4">Progress Bars</h3>
                  <div className="space-y-4">
                    <ProgressBar progress={progress} variant="primary" showLabel />
                    <ProgressBar progress={75} variant="success" />
                    <ProgressBar progress={50} variant="warning" />
                    <ProgressBar progress={25} variant="error" />
                    <div>
                      <p className="text-sm text-white/60 mb-2">Indeterminate</p>
                      <ProgressBar variant="primary" />
                    </div>
                    <div className="flex gap-2">
                      <AnimatedButton
                        size="sm"
                        variant="secondary"
                        onClick={() => setProgress(Math.max(0, progress - 10))}
                      >
                        -10%
                      </AnimatedButton>
                      <AnimatedButton
                        size="sm"
                        variant="secondary"
                        onClick={() => setProgress(Math.min(100, progress + 10))}
                      >
                        +10%
                      </AnimatedButton>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </FadeIn>

        {/* Micro-interactions */}
        <FadeIn delay={0.3}>
          <Card variant="glass">
            <CardHeader>
              <CardTitle>Micro-interactions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {/* Animated Buttons */}
                <div>
                  <h3 className="font-semibold mb-4">Animated Buttons</h3>
                  <div className="flex flex-wrap gap-3">
                    <AnimatedButton variant="primary">Primary</AnimatedButton>
                    <AnimatedButton variant="secondary">Secondary</AnimatedButton>
                    <AnimatedButton variant="danger">Danger</AnimatedButton>
                    <AnimatedButton variant="ghost">Ghost</AnimatedButton>
                    <AnimatedButton loading={loading} onClick={handleLoadingDemo}>
                      {loading ? 'Loading...' : 'Test Loading'}
                    </AnimatedButton>
                  </div>
                </div>

                {/* Animated Cards */}
                <div>
                  <h3 className="font-semibold mb-4">Animated Cards</h3>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <AnimatedCard hover glow className="p-4">
                      <h4 className="font-semibold mb-2">Hover + Glow</h4>
                      <p className="text-sm text-white/60">
                        Lifts on hover with glow effect
                      </p>
                    </AnimatedCard>

                    <AnimatedCard hover tilt className="p-4">
                      <h4 className="font-semibold mb-2">Hover + Tilt</h4>
                      <p className="text-sm text-white/60">
                        3D tilt effect on hover
                      </p>
                    </AnimatedCard>

                    <AnimatedCard hover glow tilt className="p-4">
                      <h4 className="font-semibold mb-2">All Effects</h4>
                      <p className="text-sm text-white/60">
                        Combined hover effects
                      </p>
                    </AnimatedCard>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </FadeIn>

        {/* Stagger Animation Demo */}
        <FadeIn delay={0.4} stagger staggerDelay="normal">
          <Card variant="glass">
            <CardHeader>
              <CardTitle>Stagger Animation</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
                  <ScaleIn key={i} delay={i * 0.05}>
                    <div className="aspect-square bg-gradient-to-br from-blue-500/20 to-purple-500/20 rounded-lg flex items-center justify-center">
                      <span className="text-2xl font-bold">{i}</span>
                    </div>
                  </ScaleIn>
                ))}
              </div>
            </CardContent>
          </Card>
        </FadeIn>

        {/* Accessibility Note */}
        <FadeIn delay={0.5}>
          <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
            <h3 className="font-semibold mb-2 text-yellow-400">
              ♿ Accessibility Built-in
            </h3>
            <p className="text-sm text-white/80">
              All animations respect <code className="bg-black/30 px-2 py-1 rounded">prefers-reduced-motion</code>.
              Users with motion sensitivity will see instant transitions instead of animations.
            </p>
          </div>
        </FadeIn>
      </div>
    </div>
  );
}
