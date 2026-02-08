import { useEffect } from 'react';
import { useLayoutStore } from '../stores/layoutStore';
import { Breadcrumbs } from '../components/layout';
import { Analytics } from './Analytics';

export function AnalyticsPage() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);

  useEffect(() => {
    setBreadcrumbs([{ label: 'Analytics' }]);
  }, [setBreadcrumbs]);

  return (
    <div className="space-y-6">
      <Breadcrumbs items={[{ label: 'Analytics' }]} />
      <Analytics />
    </div>
  );
}
