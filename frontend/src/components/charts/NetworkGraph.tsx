import React, { useRef, useEffect, useState } from 'react';

interface Node {
  id: string;
  label: string;
  x: number;
  y: number;
  size: number;
  color: string;
}

interface Edge {
  from: string;
  to: string;
  strength: number; // 0-1
}

interface NetworkGraphProps {
  nodes: Omit<Node, 'x' | 'y'>[];
  edges: Edge[];
  width?: number;
  height?: number;
  onNodeClick?: (nodeId: string) => void;
}

export const NetworkGraph: React.FC<NetworkGraphProps> = ({
  nodes: initialNodes,
  edges,
  width = 600,
  height = 400,
  onNodeClick,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [nodes, setNodes] = useState<Node[]>([]);
  const [draggedNode, setDraggedNode] = useState<string | null>(null);
  const [offset, setOffset] = useState({ x: 0, y: 0 });

  useEffect(() => {
    // Initialize node positions
    const positioned = initialNodes.map((node, i) => ({
      ...node,
      x: width / 2 + Math.cos((i * 2 * Math.PI) / initialNodes.length) * 150,
      y: height / 2 + Math.sin((i * 2 * Math.PI) / initialNodes.length) * 150,
    }));
    setNodes(positioned);
  }, [initialNodes, width, height]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Draw edges
    edges.forEach(edge => {
      const fromNode = nodes.find(n => n.id === edge.from);
      const toNode = nodes.find(n => n.id === edge.to);
      if (!fromNode || !toNode) return;

      const alpha = Math.max(0.1, edge.strength);
      const lineWidth = 1 + edge.strength * 3;

      ctx.strokeStyle = `rgba(59, 130, 246, ${alpha})`;
      ctx.lineWidth = lineWidth;
      ctx.beginPath();
      ctx.moveTo(fromNode.x, fromNode.y);
      ctx.lineTo(toNode.x, toNode.y);
      ctx.stroke();
    });

    // Draw nodes
    nodes.forEach(node => {
      // Node circle
      ctx.fillStyle = node.color;
      ctx.beginPath();
      ctx.arc(node.x, node.y, node.size, 0, 2 * Math.PI);
      ctx.fill();

      // Node border
      ctx.strokeStyle = '#1f2937';
      ctx.lineWidth = 2;
      ctx.stroke();

      // Node label
      ctx.fillStyle = '#f9fafb';
      ctx.font = '12px Inter, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(node.label, node.x, node.y + node.size + 15);
    });
  }, [nodes, edges, width, height]);

  const handleMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const clickedNode = nodes.find(
      node => Math.sqrt((node.x - x) ** 2 + (node.y - y) ** 2) <= node.size
    );

    if (clickedNode) {
      setDraggedNode(clickedNode.id);
      setOffset({ x: x - clickedNode.x, y: y - clickedNode.y });
    }
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!draggedNode) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left - offset.x;
    const y = e.clientY - rect.top - offset.y;

    setNodes(prev =>
      prev.map(node =>
        node.id === draggedNode ? { ...node, x, y } : node
      )
    );
  };

  const handleMouseUp = () => {
    setDraggedNode(null);
  };

  const handleClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!onNodeClick || draggedNode) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const clickedNode = nodes.find(
      node => Math.sqrt((node.x - x) ** 2 + (node.y - y) ** 2) <= node.size
    );

    if (clickedNode) {
      onNodeClick(clickedNode.id);
    }
  };

  return (
    <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
      <h3 className="text-lg font-semibold mb-4">Contact Network</h3>
      <canvas
        ref={canvasRef}
        width={width}
        height={height}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
        onClick={handleClick}
        className="border border-gray-700 rounded cursor-pointer"
      />
      <div className="mt-4 text-xs text-gray-400">
        <p>• Drag nodes to reposition</p>
        <p>• Click nodes for details</p>
        <p>• Line thickness indicates communication frequency</p>
      </div>
    </div>
  );
};
