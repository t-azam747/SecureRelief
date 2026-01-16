'use client';

import React from 'react';
import Layout from '@/components/layout/Layout';
import HomePage from '@/components/home/HomePage';

export default function Page() {
  return (
    <Layout fullWidth={true}>
      <HomePage />
    </Layout>
  );
}
