export const products = {
  lifetime: {
    priceId: 'price_1RbnH2InTpoMSXou7m5p43Sh',
    name: 'Day of Timeline Beta - Lifetime Access',
    description: 'Lifetime access to Day of Timeline app including beta and all future updates',
    mode: 'payment' as const,
  },
  yearly: {
    priceId: 'price_1RbnIfInTpoMSXouPdJBHz97',
    name: 'Day of Timeline Beta - Yearly',
    description: 'Yearly subscription to Day of Timeline app with locked-in founding member pricing',
    mode: 'subscription' as const,
  },
};